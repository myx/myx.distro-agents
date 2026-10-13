#!/usr/bin/env bash
## Behavioural check on a member asking for what its task needs in one ask, run through
## --intern-tool, the path the myx.distro MCP uses. Covers: RequestPermission with entries is
## a Permission set for the asking member and its task -- one post to the human-owner by the
## team bot, each place once and by the name it was asked by, a built-in place among them,
## with its tools, a tool asked with no place as such, what a place is for under it and what
## the whole access is for once, all in the member's words; one click grants every entry and
## nothing else, confirmed once; entries that do not cover the refused call are a correction
## and nothing is posted; the set is for the task where its task_ref names a board item, else
## for the session; a set never counts as a single request; an open set is not asked twice,
## and is withdrawn as a set is; the second single request of one session for one task that
## would reach the human-owner is a correction and nothing is posted, while a set after it is
## posted; what counts as such a request, read by the operation itself, and the one number it
## is held to; and the hint of a refused call, which carries the practice the RequestPermission
## declaration carries, word for word.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists nothing of the host is
## beside it, and every scenario runs in its own workspace under this check's temp tree, in
## $MMDAPP/.local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessPermissionSetAskCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl.fixture" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl.fixture"
## THE OWNER ANSWERS LATER. The curl first on PATH is the fixture with one thing ahead of it: a
## scenario can keep the thread the owner has answered in aside (replies.later.json), and name
## a file (replies.later.when, a glob). From the first call made once that file exists, the
## thread served is the later one. So an answer arrives at one known point of a call, never by
## a clock: once the set is written beside its record.
RIG_CURL_FIXTURE="$rigTmp/bin/curl.fixture"
export RIG_CURL_FIXTURE
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
if [ -n "${RIG_SCENARIO:-}" ] && [ -f "$RIG_SCENARIO/replies.later.json" ] && [ -f "$RIG_SCENARIO/replies.later.when" ] ; then
	for rigWhen in $( cat "$RIG_SCENARIO/replies.later.when" ) ; do
		[ -e "$rigWhen" ] || continue
		mv -f "$RIG_SCENARIO/replies.later.json" "$RIG_SCENARIO/replies.json"
		break
	done
fi
exec "$RIG_CURL_FIXTURE" "$@"
RIGCURL
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST: empty. The ps first on PATH answers the whole-host listing with
## nothing, so no process of this host is taken for a run of the rig, and hands every other
## call to the real ps.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
export RIG_PS_REAL
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*) exit 0 ;;
esac
exec "$RIG_PS_REAL" "$@"
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
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}
## How many lines of a file are one text exactly.
rigLines(){ ## file, line
	LC_ALL=C awk -v wantLine="$2" '$0 == wantLine { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}
## How many lines of a file start with one text.
rigStarts(){ ## file, line start
	LC_ALL=C awk -v wantHead="$2" 'index( $0, wantHead ) == 1 { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null || printf 'no-such-file'
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}
## The pending-reply records of the scenario, oldest first by the post they stand at.
rigRecordFiles(){
	local recordFile
	for recordFile in "$rigWs/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		printf '%s\t%s\n' "$( LC_ALL=C sed -n 's/^question-ts: //p' "$recordFile" | head -1 )" "$recordFile"
	done | LC_ALL=C sort | cut -f2-
}
rigRecordCount(){
	rigRecordFiles | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigRecordFile(){ ## which, counting from 1
	rigRecordFiles | LC_ALL=C sed -n "${1:-1}p"
}
rigRecordField(){ ## field, which record (default the first)
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecordFile "${2:-1}" )" 2>/dev/null || printf 'no-record'
}
rigRecordId(){ ## which record (default the first)
	local recordId
	recordId="$( rigRecordFile "${1:-1}" )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigSetFile(){ ## which record (default the first)
	local setFile
	setFile="$( rigRecordFile "${1:-1}" )"
	printf '%s' "${setFile%.md}.set"
}
## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## Whether that text holds one line exactly: the line stands between two line breaks of it.
rigTextLine(){ ## body file, line
	case "\\n$( rigTextOf "$1" )\\n" in
		*"\\n$2\\n"*) printf 'yes' ;;
		*) printf 'no' ;;
	esac
}
## How often that text holds one piece of text.
rigTextCount(){ ## body file, text
	rigTextOf "$1" | LC_ALL=C awk -v want="$2" '{ rest = $0 ; while ( ( at = index( rest, want ) ) > 0 ) { hitCount++ ; rest = substr( rest, at + length( want ) ) ; } } END { print hitCount + 0 ; }'
}

rigBotToken="rig-bot-token-TEAM"
rigOwnToken="rig-user-token-TESTER"
rigScenarioDir=""
rigSession=""
rigWs=""
## Where the refused calls point: under no folder of this machine, so nothing any member holds
## reaches them, and nothing is ever written.
rigOut="/dev/null/rig-setask/out"
rigFar="/dev/null/rig-setask/far"
## The task of the scenarios that have one: an item of the board, named as the tooling names one.
rigItem="dispatch-20261012T1200Z-rig"
rigTaskRef=""
rigReason="the rig reworks its report files"
rigStart(){ ## scenario directory name, optional `task`: the board holds the item of the task
	rigScenarioDir="$rigTmp/$1"
	rigSession="rig-setask-$1"
	rigWs="$rigScenarioDir/ws"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/IN" "$rigScenarioDir/data/board/running"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=%s\n' "$rigBotToken" \
		> "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=%s\n' "$rigOwnToken" > "$rigWs/.local/.agents/$rigMember.agent.env"
	## Places by name: the workspace itself, and two folders outside it.
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace rig-out directory read-write "$rigOut" owner rig-far directory read-write "$rigFar" owner \
		> "$rigWs/.local/agents/directories.registry"
	rigTaskRef="the report rework"
	if [ "${2:-}" = "task" ] ; then
		printf -- '---\nstatus: dispatch-started\nowner: %s\nsession-id: %s\n---\n\n# Rework the report files\n\n## Brief\n\nThe rig rewrites its report files.\n' "$rigMember" "$rigSession" \
			> "$rigScenarioDir/data/board/running/$rigItem.md"
		rigTaskRef="the report rework, $rigItem"
	fi
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	rigThreadNow 1 ""
}
## The ts the fake Slack gives the n-th post of a scenario.
rigPostTs(){ ## n
	printf '1700000001.000%s01' "$1"
}
## The thread of one post as conversations.replies returns it, with what the owner has put on
## it: nothing, or his click.
rigThreadJson(){ ## which post, the owner's reaction name or empty
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"first"%s}],"has_more":false}\n' "$( rigPostTs "$1" )" \
		"${2:+,\"reactions\":[{\"name\":\"$2\",\"count\":2,\"users\":[\"URIGSELF1\",\"URIGOWNER\"]}]}"
}
rigThreadNow(){ ## which post, the owner's reaction name or empty
	rm -f "$rigScenarioDir/replies.later.json" "$rigScenarioDir/replies.later.when"
	rigThreadJson "$1" "$2" > "$rigScenarioDir/replies.json"
}
## The owner clicks once a file exists: the thread with his click is kept aside until then.
rigThreadLater(){ ## which post, the owner's reaction name, the file (a glob) his click waits for
	rigThreadJson "$1" "$2" > "$rigScenarioDir/replies.later.json"
	printf '%s\n' "$3" > "$rigScenarioDir/replies.later.when"
}

## How many calls that change something in Slack the scenario has made: a post, an edit, an emoji.
rigWrites(){
	LC_ALL=C awk '$0 == "chat.postMessage" || $0 == "chat.update" || $0 == "reactions.add" || $0 == "reactions.remove" { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null
}
## One served call of a tool, as the rig's member in the session rigSession. A question nobody
## answers is re-waited without end by design, so the guard is the scenario's: a killed run is
## reported as such, never as a result. With settle the guard is a quiet time: it counts from
## the first thread read this call makes, and starts again at every post, edit or emoji, so the
## call is ended only once it does nothing but wait, however long its work took before that.
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object, optional settle
	local callPid callLeft callStartLeft=120 callReads callWrites callNow
	rigKilled="no"
	callReads="$( rigCalls conversations.replies )"
	callWrites="$( rigWrites )"
	set -m
	( cd "$rigWs" && printf '%s' "$3" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_THREAD \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID="$rigSession" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigWs" --access-write-root "$rigWs/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	callLeft="$1"
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1
		if [ "${4:-}" = "settle" ] ; then
			if [ "$callStartLeft" -gt 0 ] && [ "$( rigCalls conversations.replies )" = "$callReads" ] ; then
				callStartLeft=$(( callStartLeft - 1 ))
				continue
			fi
			callNow="$( rigWrites )"
			if [ "$callNow" != "$callWrites" ] ; then
				callWrites="$callNow" ; callLeft="$1"
				continue
			fi
		fi
		callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}
## One team operation in the scenario's workspace, as no session of its own; out and err kept
## as op.out and op.err, its rc as rigOpRc.
rigOpRc=0
rigOp(){ ## operation and its arguments
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD \
		TMPDIR="$rigTmp/tmp" MDAT_DATA_ROOT="$rigScenarioDir/data" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigWs" bash "$rigTools" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" || rigOpRc=$?
}
## A write the harness refuses: prints its refusal id. What the call printed is kept as refused.out.
rigRefused(){ ## path
	rigCall 60 Write "{\"path\":\"$1\",\"content\":\"x\"}"
	cp "$rigScenarioDir/out" "$rigScenarioDir/refused.out"
	rigRefusal "$rigScenarioDir/out"
}
## What the task needs, asked in one ask: the refusal it starts from and the entries, a JSON
## list. With a quiet time it is a call nobody answers, ended by the rig once it only waits.
rigAskSet(){ ## refusal id, the entries as a JSON value, optional quiet seconds
	if [ -n "${3:-}" ] ; then
		rigCall "$3" RequestPermission "{\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\",\"entries\":$2}" settle
	else
		rigCall 120 RequestPermission "{\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\",\"entries\":$2}"
	fi
}
## One refused call asked alone, of the human-owner.
rigAskOne(){ ## refusal id, optional quiet seconds
	if [ -n "${2:-}" ] ; then
		rigCall "$2" RequestPermission "{\"to\":\"human-owner\",\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\"}" settle
	else
		rigCall 120 RequestPermission "{\"to\":\"human-owner\",\"refusal_id\":\"$1\",\"reason\":\"$rigReason\",\"task_ref\":\"$rigTaskRef\"}"
	fi
}
## Whether the session holds a grant for one call: the first word after GRANT:, or none.
rigGranted(){ ## tool, path
	rigOp --intern-op-permission-grant-read "$rigMember" --session-id "$rigSession" --tool "$1" --target "$2"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigScenarioDir/op.out" | head -1 | LC_ALL=C awk '{ print ; found = 1 ; } END { if ( ! found ) { print "none" ; } }'
}
## The emoji of the tooling's own on one post: "<placed, in order>|<taken off, in order>".
rigEmoji(){ ## which post
	printf '%s|%s' "$( LC_ALL=C awk -v want="$( rigPostTs "$1" )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions" 2>/dev/null )" \
		"$( LC_ALL=C awk -v want="$( rigPostTs "$1" )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigScenarioDir/reactions.removed" 2>/dev/null )"
}

## The one number a stream of single requests is held to, from the model's own home.
rigLimit="$( MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.PermissionHolds.include" ; printf "%s" "${agentsPermissionSingleAsks:-}"' 2>/dev/null )"
rigAssert "the number of single requests the human-owner answers for one session and one task is one number, held in one place" \
	"$rigLimit:$( LC_ALL=C grep -c '^agentsPermissionSingleAsks=' "$rigHere"/*.include "$rigHere"/*.sh 2>/dev/null | LC_ALL=C awk -F: '{ total += $NF ; } END { print total + 0 ; }' )" "1:1"

echo "-- a member asks for what its task needs in one ask: one post, and one click grants all of it --"
rigStart asked-set task
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
[ -n "$rigFirst" ] || rigRefuse "the rig produced no refusal to ask permission for"
## His click lands once the set is written beside its record.
rigThreadLater 1 unlock "$rigWs/.local/agents/pending/*.set"
rigAskSet "$rigFirst" '["Read,Write:@rig-out:reports/**","purpose: write the report files there","Read,Grep,Glob:@rig-far:docs/**","Read:@.skillset-.local:magic-tester/**","WebSearch"]'
rigAssert "the ask comes back answered: allow-set, with the grant of the whole set" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigLines "$rigScenarioDir/out" "GRANT: set 7 entries for $rigMember" )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: allow-set:1"
rigSetId="$( rigRecordId )"
rigAssert "and says it was asked as one set, for whom and for which task, and what one answer does" \
	"$( rigLines "$rigScenarioDir/out" "NOTE: asked as one Permission set, pending reply $rigSetId: 7 entries for $rigMember, for the task $rigItem. One answer of the human-owner covers them all: allow-set grants every entry, deny grants none, and edit returns the set to you with the change to make." )" 1
rigAssert "one post to the human-owner, the team bot's, a message of its own, and one record: a permission set of the asking member" \
	"$( cat "$rigScenarioDir/posted-as.1" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.1" '"thread_ts"' ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField owner ):$( rigRecordField address-to ):$( rigRecordField ask-identity ):$( rigRecordField item )" \
	"$rigBotToken:no:1:permission-set:$rigMember:human-owner:bot:$rigItem"
rigAssert "its set is for the task, this session and this member alone, and keeps every entry as one tool and its exact target" \
	"$( rigLines "$( rigSetFile )" 'scope: task' ):$( rigLines "$( rigSetFile )" "item: $rigItem" ):$( rigLines "$( rigSetFile )" "session-id: $rigSession" ):$( rigLines "$( rigSetFile )" "participants: $rigMember" ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigLines "$( rigSetFile )" "entry: Write:$rigOut/reports/**" ):$( rigLines "$( rigSetFile )" "entry: Glob:$rigFar/docs/**" ):$( rigLines "$( rigSetFile )" 'entry: WebSearch' )" \
	"1:1:1:1:7:1:1:1"
rigAssert "the post says it is a permission set for this task, and how one answer covers it" \
	"$( rigTextLine "$rigScenarioDir/post.1" '# 🔐 Permission set' ):$( rigTextLine "$rigScenarioDir/post.1" 'May the participants have these, for this task only?' ):$( rigHolds "$rigScenarioDir/post.1" 'allow-set' ):$( rigTextLine "$rigScenarioDir/post.1" "- $rigMember" )" \
	"yes:yes:yes:yes"
rigAssert "a place asked by its name is shown by that name, with every tool asked for it: two folders, each by the name of its place" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- `rig-out:reports/**` — Read, Write' ):$( rigTextLine "$rigScenarioDir/post.1" '- `rig-far:docs/**` — Read, Grep, Glob' )" "yes:yes"
rigAssert "a built-in place is shown by its own name, as it was asked, never by where its files lie" \
	"$( rigTextLine "$rigScenarioDir/post.1" '- `.skillset-.local:magic-tester/**` — Read' )" "yes"
rigAssert "a tool asked with no place is shown as a tool, for any target" "$( rigTextLine "$rigScenarioDir/post.1" '- WebSearch — any target' )" "yes"
rigAssert "what a place is for stands under it, and what the whole access is for stands once, both in the member's words" \
	"$( rigTextLine "$rigScenarioDir/post.1" '  - write the report files there' ):$( rigTextLine "$rigScenarioDir/post.1" '**💡 What it is for**' ):$( rigTextLine "$rigScenarioDir/post.1" "$rigReason" ):$( rigTextCount "$rigScenarioDir/post.1" "$rigReason" )" \
	"yes:yes:yes:1"
rigAssert "every place stands once, and no path of this machine is shown" \
	"$( rigTextCount "$rigScenarioDir/post.1" 'rig-out:reports/**' ):$( rigTextCount "$rigScenarioDir/post.1" 'rig-far:docs/**' ):$( rigTextCount "$rigScenarioDir/post.1" '.skillset-.local:magic-tester/**' ):$( rigTextCount "$rigScenarioDir/post.1" 'WebSearch' ):$( rigTextCount "$rigScenarioDir/post.1" '/dev/null' ):$( rigTextCount "$rigScenarioDir/post.1" '`/' )" \
	"1:1:1:1:0:0"
rigAssert "the set's own answer emoji are placed under it by the bot; answered, it gets the answered mark, and the bot takes its own answer emoji off it" "$( rigEmoji 1 )" "x unlock white_check_mark|x unlock"
rigAssert "the answer is confirmed once, in the thread of the post, by the bot: the one other post" \
	"$( rigCalls chat.postMessage ):$( cat "$rigScenarioDir/posted-as.2" 2>/dev/null ):$( rigHolds "$rigScenarioDir/post.2" "\"thread_ts\":\"$( rigPostTs 1 )\"" ):$( rigHolds "$rigScenarioDir/post.2" "Read: \`allow-set\` by human-owner. Granted: 7 permission(s) to $rigMember, for this task only." )" \
	"2:$rigBotToken:yes:yes"
rigAssert "its record is closed with that verdict" "$( rigRecordField status ):$( rigRecordField verdict )" "reply-received:allow-set"
rigAssert "every entry is granted for the task: the refused call, the rest of its folder, the other place by the tools asked there, and nothing that was not asked" \
	"$( rigGranted Write "$rigOut/reports/one.txt" ):$( rigGranted Read "$rigOut/reports/deep/two.txt" ):$( rigGranted Grep "$rigFar/docs/a.md" ):$( rigGranted Write "$rigFar/docs/a.md" ):$( rigGranted Write "$rigOut/else/x.txt" )" \
	"task:task:task:none:none"

echo "-- a set is no single request: the first call asked alone after it is still posted --"
rigOther="$( rigRefused "$rigFar/docs/new.md" )"
rigThreadNow 3 ""
rigAskOne "$rigOther" 8
rigAssert "a call the set did not ask for, asked alone: a prompt of its own, a single permission, open" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind 2 ):$( rigRecordField refusal-id 2 ):$( rigRecordField status 2 )" \
	"yes:3:2:permission:$rigOther:reply-pending"

echo "-- entries that do not cover the refused call: a correction, and nothing is posted --"
rigStart not-covered task
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
rigAskSet "$rigFirst" '["Read,Grep:@rig-out:reports/**","Read,Write:@rig-far:docs/**"]'
rigAssert "the tool of the refused call is not asked for its place: a correction that names the call, nothing posted, nothing recorded" \
	"$rigKilled:$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was asked. The entries do not cover the call that was refused: Write on rig-out:reports/one.txt.' ):$( rigCalls chat.postMessage ):$( rigRecordCount )" \
	"no:1:0:0"
rigAskSet "$rigFirst" '["Raed,Write:@rig-out:reports/**"]'
rigAssert "an entry that names no tool the permission model knows: a correction that names the entry, nothing posted" \
	"$rigKilled:$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was asked.' ):$( rigHolds "$rigScenarioDir/out" "names a tool the permission model does not know: 'Raed'" ):$( rigCalls chat.postMessage ):$( rigRecordCount )" \
	"no:1:yes:0:0"
rigAskSet "$rigFirst" '["Read,Write:@rig-nowhere:OUT/**"]'
rigAssert "an entry that names no known place: a correction, nothing posted" \
	"$rigKilled:$( rigStarts "$rigScenarioDir/out" 'CORRECTION: RequestPermission: nothing was asked' ):$( rigHolds "$rigScenarioDir/out" 'Read:@rig-nowhere:OUT/**' ):$( rigCalls chat.postMessage ):$( rigRecordCount )" \
	"no:1:yes:0:0"
rigAskSet "$rigFirst" '["Write:@rig-out:reports/one.txt"]' 8
rigAssert "control: an entry for exactly the refused call covers it, and the set is posted" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind ):$( rigLines "$( rigSetFile )" "entry: Write:$rigOut/reports/one.txt" )" "yes:1:1:permission-set:1"

echo "-- a second call asked alone of the human-owner for the same task is not posted; a set after it is --"
rigStart stream task
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
rigThreadNow 1 one
rigAskOne "$rigFirst"
rigAssert "control: the first call asked alone is posted to him, and his allow-once is applied and confirmed" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: allow-once:2:1:permission:reply-received"
rigStreamId="$( rigRecordId )"
rigSecond="$( rigRefused "$rigOut/reports/two.txt" )"
rigThreadNow 3 ""
rigAskOne "$rigSecond"
rigAssert "the second call asked alone comes back as a correction that names the answered request and the rule" \
	"$rigKilled:$( rigLines "$rigScenarioDir/out" "CORRECTION: RequestPermission: nothing was posted. A session asks the human-owner for one call alone at most $rigLimit time(s) for a task, and he has already answered that many of this session for this task: pending reply $rigStreamId. Ask once for what the rest of the task needs: call RequestPermission again with this refusal_id and entries, one entry for each place, written Tool,Tool:<folder>/**, with every tool you will use there, in every workspace the task touches, and say what the access is for. The entries must cover the refused call." )" \
	"no:1"
rigAssert "nothing was posted, edited or recorded for it" \
	"$( rigCalls chat.postMessage ):$( rigCalls chat.update ):$( rigRecordCount ):$( rigGranted Write "$rigOut/reports/two.txt" )" "2:0:1:none"
rigThreadLater 3 x "$rigWs/.local/agents/pending/*.set"
rigAskSet "$rigSecond" '["Read,Write:@rig-out:reports/**"]'
rigAssert "the same refusal asked with entries is posted: a set never triggers the rule, and his cross on it is a deny for all of it" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigVerdictLine ):$( rigRecordCount ):$( rigRecordField kind 2 ):$( rigRecordField verdict 2 ):$( rigCalls chat.postMessage ):$( rigHolds "$rigScenarioDir/post.4" "Read: \`deny\` by human-owner. Nothing is granted to $rigMember." ):$( rigGranted Write "$rigOut/reports/two.txt" )" \
	"no:ASK-RESULT: RECEIVED:VERDICT: deny:2:permission-set:deny:4:yes:none"

echo "-- with no board item for the task the set is for the session; open, it is not asked twice; it is withdrawn as a set is --"
rigStart session-scope
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
## The entries as one text, an entry a line, are taken as the list is.
rigAskSet "$rigFirst" '"Read,Write:@rig-out:reports/**\nRead:@rig-far"' 8
rigAssert "posted and open: a set of scope session that names no item, shown as for this session only" \
	"$rigKilled:$( rigCalls chat.postMessage ):$( rigRecordCount ):$( rigRecordField kind ):$( rigRecordField status ):$( rigLines "$( rigSetFile )" 'scope: session' ):$( rigLines "$( rigSetFile )" 'item: ' ):$( rigStarts "$( rigSetFile )" 'entry: ' ):$( rigTextLine "$rigScenarioDir/post.1" 'May the participants have these, for this session only?' ):$( rigTextLine "$rigScenarioDir/post.1" '- `rig-far:**` — Read' )" \
	"yes:1:1:permission-set:reply-pending:1:1:3:yes:yes"
rigAssert "nothing is granted while he has not answered" "$( rigGranted Write "$rigOut/reports/one.txt" )" "none"
rigAskSet "$rigFirst" '["Read,Write:@rig-out:reports/**"]'
rigAssert "asked again while it is open: already open, nothing posted, nothing recorded" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigCalls chat.postMessage ):$( rigRecordCount )" "no:ASK-RESULT: ALREADY-OPEN:1:1"
rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig no longer needs the folder\"}"
rigAssert "withdrawn by its asker: closed with no verdict, nothing granted, its post left with no way to answer" \
	"$rigKilled:$( rigFirstLine "$rigScenarioDir/out" ):$( rigRecordField status ):$( rigRecordField verdict ):$( rigGranted Write "$rigOut/reports/one.txt" ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" 'Permission set' ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" 'rig-out:reports/**' ):$( rigHolds "$rigScenarioDir/edit.$( rigPostTs 1 )" 'allow-set' )" \
	"no:ASK-RESULT: WITHDRAWN:withdrawn:none:none:yes:yes:no"

echo "-- what counts as a call asked alone and answered by the human-owner, as the operation reads it --"
rigStart counted task
printf -- '---\nstatus: dispatch-started\nowner: %s\n---\n\n# Another task\n' "$rigMember" > "$rigScenarioDir/data/board/running/dispatch-20261012T1300Z-other.md"
mkdir -p "$rigWs/.local/agents/pending"
rigRecord(){ ## id, status, owner, session, kind, item (or -), task ref, verdict (or -), answered by (or -)
	{
		printf -- '---\nstatus: %s\nowner: %s\nsession-id: %s\nkind: %s\naddress-to: human-owner\n' "$2" "$3" "$4" "$5"
		[ "$6" = "-" ] || printf 'item: %s\n' "$6"
		printf 'task-ref: %s\n' "$7"
		[ "$8" = "-" ] || printf 'verdict: %s\n' "$8"
		[ "$9" = "-" ] || printf 'answered-by: %s\n' "$9"
		printf -- '---\n\n# Question asked\n\nrig\n'
	} > "$rigWs/.local/agents/pending/$1.md"
}
rigSingles(){ ## member, session, task ref -> the first line of what the operation prints
	rigOp --intern-op-permission-single-asks "$1" --session-id "$2" --task-ref "$3"
	rigFirstLine "$rigScenarioDir/op.out"
}
rigRecord rec-owner reply-received "$rigMember" sess-1 permission "$rigItem" "the rework, $rigItem" allow-once URIGOWNER
rigAssert "a single permission he answered, of this member, this session and this task: counted, and the next is stopped" \
	"$( rigSingles "$rigMember" sess-1 "more of the rework, $rigItem" ):$( rigLines "$rigScenarioDir/op.out" 'ANSWERED: rec-owner' )" "SINGLE-ASKS: stop 1 $rigLimit:1"
rigAssert "another session, another member, another task: none counted" \
	"$( rigSingles "$rigMember" sess-2 "the rework, $rigItem" )|$( rigSingles magic-developer sess-1 "the rework, $rigItem" )|$( rigSingles "$rigMember" sess-1 'dispatch-20261012T1300Z-other' )" \
	"SINGLE-ASKS: go 0 $rigLimit|SINGLE-ASKS: go 0 $rigLimit|SINGLE-ASKS: go 0 $rigLimit"
rigRecord rec-denied reply-received "$rigMember" sess-3 permission "$rigItem" "$rigItem" deny human-owner
rigAssert "his deny is an answer too, and so is one recorded under his name" "$( rigSingles "$rigMember" sess-3 "$rigItem" )" "SINGLE-ASKS: stop 1 $rigLimit"
rigRecord rec-member reply-received "$rigMember" sess-4 permission "$rigItem" "$rigItem" allow-session magic-coordinator
rigAssert "a call a member or the coordinator answered never reached him: not counted" "$( rigSingles "$rigMember" sess-4 "$rigItem" )" "SINGLE-ASKS: go 0 $rigLimit"
rigRecord rec-withdrawn withdrawn "$rigMember" sess-5 permission "$rigItem" "$rigItem" - -
rigRecord rec-open reply-pending "$rigMember" sess-5 permission "$rigItem" "$rigItem" - -
rigAssert "one withdrawn and one still open are no answers of his: not counted" "$( rigSingles "$rigMember" sess-5 "$rigItem" )" "SINGLE-ASKS: go 0 $rigLimit"
rigRecord rec-set reply-received "$rigMember" sess-6 permission-set "$rigItem" "$rigItem" allow-set URIGOWNER
printf 'scope: task\nitem: %s\nsession-id: sess-6\nparticipants: %s\nentry: Read:/nowhere/rig/**\n' "$rigItem" "$rigMember" > "$rigWs/.local/agents/pending/rec-set.set"
rigAssert "a set asked as a set never counts" "$( rigSingles "$rigMember" sess-6 "$rigItem" )" "SINGLE-ASKS: go 0 $rigLimit"
rigRecord rec-joined reply-received "$rigMember" sess-7 permission-set "$rigItem" "$rigItem" allow-set URIGOWNER
printf 'scope: session\nitem: %s\nsession-id: sess-7\nparticipants: %s\nentry: Write:/nowhere/rig/one\nentry: Write:/nowhere/rig/two\nrefusal: refusal-a\tWrite:/nowhere/rig/one\nrefusal: refusal-b\tWrite:/nowhere/rig/two\n' "$rigItem" "$rigMember" \
	> "$rigWs/.local/agents/pending/rec-joined.set"
rigAssert "a prompt that single calls were added to, answered by him, is single calls that reached him: counted" "$( rigSingles "$rigMember" sess-7 "$rigItem" )" "SINGLE-ASKS: stop 1 $rigLimit"
rigRecord rec-words reply-received "$rigMember" sess-8 permission - 'Tidy the notes' allow-once URIGOWNER
rigAssert "with no board item the task is the one the member names, however it spaces or cases the words" \
	"$( rigSingles "$rigMember" sess-8 'tidy  the   NOTES' )|$( rigSingles "$rigMember" sess-8 'another job' )" "SINGLE-ASKS: stop 1 $rigLimit|SINGLE-ASKS: go 0 $rigLimit"

echo "-- the hint of a refused call carries the practice of the RequestPermission declaration, word for word --"
rigStart hint
rigFirst="$( rigRefused "$rigOut/reports/one.txt" )"
rigHint="$rigScenarioDir/refused.out"
rigAssert "the line after the refusal id says it is no verdict, and names the tool and the id to ask with" \
	"$( LC_ALL=C awk 'seenId { print substr( $0, 1, 33 ) ; exit ; } /^REFUSAL-ID: / { seenId = 1 ; }' "$rigHint" ):$( rigHolds "$rigHint" "ask for it with RequestPermission refusal_id=$rigFirst, a reason and a task_ref." )" \
	"This is a refusal, not a verdict.:yes"
## The practice as the declaration carries it: from its first numbered line to the sentence that ends it.
rigPractice="$( LC_ALL=C awk 'index( $0, "\"name\":\"RequestPermission\"" ) { from = index( $0, "How to ask, in five lines: (1) " ) ; upTo = index( $0, " The details follow." ) ; if ( from && upTo > from ) { text = substr( $0, from + 27, upTo - from - 27 ) ; for ( lineNo = 2 ; lineNo <= 9 ; lineNo++ ) { gsub( " \\(" lineNo "\\) ", "\n(" lineNo ") ", text ) ; } print text ; } exit ; }' "$rigHere/AgentsOpenAiChatWire.sh" )"
rigPracticeLines="$( printf '%s\n' "$rigPractice" | LC_ALL=C grep -c . )"
rigAssert "the declaration carries the practice, in at most five lines, each numbered" \
	"$( [ "$rigPracticeLines" -ge 3 ] && [ "$rigPracticeLines" -le 5 ] && printf in-five || printf "$rigPracticeLines" ):$( printf '%s\n' "$rigPractice" | LC_ALL=C grep -c -v '^([1-5]) ' )" "in-five:0"
## Whether a text says one piece of text: y, or the piece it lacks.
rigSaid(){ ## text, piece
	case "$1" in
		*"$2"*) printf 'y' ;;
		*) printf '[%s]' "$2" ;;
	esac
}
rigHintHeld=0
while IFS= read -r rigPracticeLine ; do
	[ -n "$rigPracticeLine" ] || continue
	[ "$( rigLines "$rigHint" "$rigPracticeLine" )" = "1" ] || rigHintHeld=$(( rigHintHeld + 1 ))
done <<< "$rigPractice"
rigAssert "the hint holds every line of it once, word for word" "$rigHintHeld" 0
rigAssert "the practice says each thing the task is asked by: what the task needs, once, places as folders, every tool, every workspace, what for, and one call alone only for a single case" \
	"$( for rigWord in 'work out what the task needs' 'Ask once' '/**' 'every tool' 'every workspace' 'what the access is for' 'one call alone' ; do rigSaid "$rigPractice" "$rigWord" ; done )" "yyyyyyy"
rigOp --intern-op-permission-refusal-log "$rigMember" --session-id "$rigSession" --tool Read --target /nowhere/rig/hint --reason 'a read the rig made up'
rigAssert "the refusal record's own operation gives the hint, so a native client's refusal says the same" \
	"$( rigStarts "$rigScenarioDir/op.out" 'refusal-' ):$( rigStarts "$rigScenarioDir/op.out" 'HINT: This is a refusal, not a verdict.' ):$( rigStarts "$rigScenarioDir/op.out" 'HINT: (1) ' )" "1:1:1"
rigDeclared="$( LC_ALL=C grep -F '"name":"RequestPermission"' "$rigHere/AgentsOpenAiChatWire.sh" )"
rigAssert "the declaration takes entries, a list, and holds no apostrophe" \
	"$( rigSaid "$rigDeclared" '"entries":{"type":"array","items":{"type":"string"}' ):$( printf '%s' "$rigDeclared" | LC_ALL=C tr -c -d "'" | LC_ALL=C wc -c | LC_ALL=C tr -d ' ' )" "y:0"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method" "$rigUnknown" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION SET ASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION_SET_ASK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
