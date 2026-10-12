#!/usr/bin/env bash
## Behavioural check on what a permission post asks for. Its first line, under the title, is
## made from the refused call as the refusal record holds it -- the tool, the target, who it
## was refused for -- and says that an allow grants exactly that. The asker's own words, the
## question and the reason, are shown under `Why this task needs it` and nowhere else, so a
## post never asks in free text for more than its answer grants. The seen fault: a question
## asking for a whole folder, over a grant written for one file. Proved end to end: the same
## tool and target stand in the first line of the post and in the confirmation of the grant.
## The same under the second name of the tools, in the record, and in the post edited once
## the request is withdrawn. Offline: a Slack-shaped fake curl, first on PATH, answers every
## request.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPermissionPostLeadCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}
rigVerdictLine(){
	LC_ALL=C awk '/^VERDICT: / { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-verdict-line" ; } }' "$rigScenarioDir/out"
}
rigRecordFile(){
	local recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] && { printf '%s' "$recordFile" ; return 0 ; }
	done
	printf '%s' "$rigScenarioDir/no-record"
}
rigRecordId(){
	local recordId
	recordId="$( rigRecordFile )" ; recordId="${recordId##*/}"
	printf '%s' "${recordId%.md}"
}
rigRefusal(){ ## output file -> the refusal id it printed
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | head -1
}
## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## The first line of a permission post, under its title: what the person is asked to allow.
rigLeadOf(){ ## body file
	local leadText
	leadText="$( rigTextOf "$1" )"
	case "$leadText" in
		*'# 🔐 Permission\n\n'*) leadText="${leadText#*'# 🔐 Permission\n\n'}" ; printf '%s' "${leadText%%'\n'*}" ;;
		*) printf 'no-permission-title' ;;
	esac
}
## What stands under `Why this task needs it`, up to the next heading.
rigWhyOf(){ ## body file
	local whyText
	whyText="$( rigTextOf "$1" )"
	case "$whyText" in
		*'**❔ Why this task needs it**\n'*) whyText="${whyText#*'**❔ Why this task needs it**\n'}" ; printf '%s' "${whyText%%'\n\n**'*}" ;;
		*) printf 'no-why-heading' ;;
	esac
}
## How many times a text stands in the text of a post.
rigTimesIn(){ ## body file, text
	rigTextOf "$1" | LC_ALL=C awk -v want="$2" '{ rest = $0 ; while ( ( at = index( rest, want ) ) > 0 ) { hitCount++ ; rest = substr( rest, at + length( want ) ) ; } } END { print hitCount + 0 ; }'
}

rigScenarioDir=""
rigScenarioName=""
rigStart(){ ## scenario directory name
	rigScenarioName="$1"
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents" "$rigScenarioDir/ws/IN"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
		> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The thread of the scenario's first post as conversations.replies returns it: a click of
## the one the post is addressed to, beside the tooling's own.
rigClicked(){ ## reaction name
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first","reactions":[{"name":"%s","count":2,"users":["URIGSELF1","URIGOWNER"]}]}],"has_more":false}\n' "$1" > "$rigScenarioDir/replies.json"
}
rigKilled=""
rigCall(){ ## guard seconds, tool, argument object
	local callPid callLeft="$1"
	rigKilled="no"
	set -m
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDAT_SPAWN_SESSION_ID="rig-lead-$rigScenarioName" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) > "$rigScenarioDir/out" 2> "$rigScenarioDir/err" &
	callPid=$!
	set +m
	while kill -0 "$callPid" 2>/dev/null && [ "$callLeft" -gt 0 ] ; do
		sleep 1 ; callLeft=$(( callLeft - 1 ))
	done
	if kill -0 "$callPid" 2>/dev/null ; then
		rigKilled="yes"
		{ kill -TERM -- "-$callPid" ; sleep 1 ; kill -KILL -- "-$callPid" ; wait "$callPid" ; } 2>/dev/null
	fi
	wait "$callPid" 2>/dev/null || :
}

## The asker's words, as the seen fault had them: they name a whole folder, and the refused
## call, which is all a grant is written for, is one file in it.
rigFile="/dev/null/rig-lead/folder/one-file.txt"
rigAsked="Allow Write on every file under the rig folder."
rigWhy="The task rewrites one page there."
rigLead="Allow **Write** on \`$rigFile\` for **$rigMember**? An allow grants exactly that, and nothing wider."

echo "-- the first line is made from the refused call, and the asker's words are the reason --"
rigStart owner
rigCall 60 Write "{\"path\":\"$rigFile\",\"content\":\"x\"}"
rigRefusalId="$( rigRefusal "$rigScenarioDir/out" )"
[ -n "$rigRefusalId" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigClicked one
rigCall 90 RequestPermission "{\"to\":\"human-owner\",\"question\":\"$rigAsked\",\"refusal_id\":\"$rigRefusalId\",\"reason\":\"$rigWhy\",\"task_ref\":\"dispatch-rig\"}"
[ -f "$rigScenarioDir/post.1" ] || rigRefuse "the permission was never posted, so there is no post to read: $( head -1 "$rigScenarioDir/out" )"
rigAssert "it ran to its answer"                          "$rigKilled:$( rigVerdictLine )" "no:VERDICT: allow-once"
rigAssert "the first line under the title names the refused tool, its target and who it was refused for, and what an allow grants" "$( rigLeadOf "$rigScenarioDir/post.1" )" "$rigLead"
## Parenthesised patterns keep bash 3.2 from closing this substitution early.
rigAssert "the asker's question is not that line"         "$( case "$( rigLeadOf "$rigScenarioDir/post.1" )" in (*"every file under"*) printf asker ;; (*) printf tooling ;; esac )" tooling
rigAssert "the asker's words stand under Why this task needs it: the question, then the reason" "$( rigWhyOf "$rigScenarioDir/post.1" )" "$rigAsked\\n$rigWhy"
rigAssert "and nowhere else in the post: each stands once" "$( rigTimesIn "$rigScenarioDir/post.1" "$rigAsked" ):$( rigTimesIn "$rigScenarioDir/post.1" "$rigWhy" )" "1:1"
rigAssert "the refused call is still shown as its record holds it" "$( rigHolds "$rigScenarioDir/post.1" "**🚫 Refused call**\\n- tool: Write\\n- target: $rigFile\\n- refused for: $rigMember\\n- refusal: $rigRefusalId" )" yes
rigAssert "the lines that say how to answer are as before" "$( rigHolds "$rigScenarioDir/post.1" 'click ❌ to deny, 1️⃣ to allow once, or 🔁 to allow for this session' )" yes
## What the click granted, as the tooling says it in the thread: the same tool, target and member.
rigAssert "what the click granted is what the first line asked: the confirmation names the same tool, target and member" \
	"$( rigHolds "$rigScenarioDir/post.2" "Granted: Write on $rigFile to $rigMember, for this one call." )" yes
rigAssert "the grant itself is written for that one refused call" "$( LC_ALL=C grep -c -x "GRANT: once $rigRefusalId" "$rigScenarioDir/out" )" 1
rigAssert "the record keeps the post as it was sent: the same first line" \
	"$( LC_ALL=C awk 'seenTitle && NF { print ; exit ; } /^# 🔐 Permission/ { seenTitle = 1 ; }' "$( rigRecordFile )" 2>/dev/null )" "$rigLead"

echo "-- the same under the second name of the tools --"
rigStart second-name
rigCall 60 Write "{\"path\":\"$rigFile\",\"content\":\"x\"}"
rigRefusalId="$( rigRefusal "$rigScenarioDir/out" )"
[ -n "$rigRefusalId" ] || rigRefuse "the rig produced no refusal to ask permission for"
rigClicked one
rigCall 90 AskUserQuestion "{\"to\":\"human-owner\",\"kind\":\"permission\",\"question\":\"$rigAsked\",\"refusal_id\":\"$rigRefusalId\",\"reason\":\"$rigWhy\",\"task_ref\":\"dispatch-rig\"}"
rigAssert "its first line is made from the refused call too" "$( rigLeadOf "$rigScenarioDir/post.1" )" "$rigLead"
rigAssert "and the asker's words are the reason there too" "$( rigWhyOf "$rigScenarioDir/post.1" ):$( rigTimesIn "$rigScenarioDir/post.1" "$rigAsked" )" "$rigAsked\\n$rigWhy:1"

echo "-- a request withdrawn: its post, edited, still leads with the refused call --"
rigStart withdrawn
rigCall 60 Write "{\"path\":\"$rigFile\",\"content\":\"x\"}"
rigRefusalId="$( rigRefusal "$rigScenarioDir/out" )"
[ -n "$rigRefusalId" ] || rigRefuse "the rig produced no refusal to ask permission for"
## Nobody answers: the asking call is stopped once its post is up and recorded.
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"first"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigCall 30 RequestPermission "{\"to\":\"human-owner\",\"question\":\"$rigAsked\",\"refusal_id\":\"$rigRefusalId\",\"reason\":\"$rigWhy\",\"task_ref\":\"dispatch-rig\"}"
[ -f "$( rigRecordFile )" ] || rigRefuse "the permission that is to be withdrawn was never recorded: $( head -1 "$rigScenarioDir/out" )"
rigCall 60 RequestPermission "{\"pending_id\":\"$( rigRecordId )\",\"withdraw\":\"the rig went on by itself\"}"
rigAssert "the post was edited"                           "$( cat "$rigScenarioDir/edited" 2>/dev/null | head -1 )" "1700000001.000101"
rigAssert "to the same text, led by the refused call"     "$( rigLeadOf "$rigScenarioDir/edit.1700000001.000101" )" "$rigLead"
rigAssert "with the asker's words still the reason, and no How to answer" "$( rigWhyOf "$rigScenarioDir/edit.1700000001.000101" ):$( rigHolds "$rigScenarioDir/edit.1700000001.000101" 'How to answer' )" "$rigAsked\\n$rigWhy:no"

rigAssert "no request left this box"                    "$( cat "$rigTmp"/*/curl.log | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION POST LEAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a permission post can ask, in the asker's own words, for more than its answer grants" >&2
	echo "  fix:  repair the question and reason parts of sh-lib/templates/request-permission.post.format.md, or the filling of parts in AgentsAskPostFill.awk -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_POST_LEAD: OK (%d assertions, offline)\n' "$rigPassCount"
