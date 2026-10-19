#!/usr/bin/env bash
## Behavioural check on who a post is addressed to, run rather than read. The five posting
## tools, SendMessage, SubagentHandback, ReportFindings, PushNotification and Artifact, take
## address_to as the tools that ask take it: the member send names it in the header of the
## post, by its one rule, exactly as it does for a question. With none the post is as it
## always was, headed @here in a thread, and never refused. A handback that names nobody is
## addressed to the caller, the member that made the spawn call, as the session's own spawn
## record names it, else, for a record written before that line was, the member of the
## session that started it, and to nobody where neither is named: a default never fails a
## handback. A word is an account or a conversation only by the whole shape of a Slack id,
## never by its first letters, and a word that names nobody is refused in one plain line.
## A DISMISSED sent with SendMessage and address_to dismisses the member it names and nobody
## else, read by the one dismissal rule the Wait uses, and no text inside a message body
## dismisses anybody. Offline: the Slack-shaped fake curl is first on PATH, model CLIs on
## PATH only log, the skillset is a fixture, and each scenario has its own workspace under
## the workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigWire="$rigHere/AgentsOpenAiChatWire.sh"
## The posting member, the member whose session started it, and a third one.
rigMember="rig-helper"
rigLead="rig-lead"
rigOther="rig-other"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsPostAddresseeCheck.XXXXXX" )" || exit 1
## The parent's run, alive by the one rule a run is alive by: a stand-in whose own --session-id is
## the parent's id, ended with the rig, through the one way a check signals what it kept
## (sh-test/check-fixtures/rig-processes.include.sh). A route to a session goes to a member that runs there.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
bash -c 'sleep 1800 ; :' rig-run --session-id rig-parent-id > /dev/null 2>&1 < /dev/null &
rigParentPid=$! ; rigProcNote "$rigParentPid"
disown "$rigParentPid" 2> /dev/null || :
trap 'rigProcSignalWithChildren TERM "$rigParentPid" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp" "$rigTmp/skills"
for rigName in "$rigMember" "$rigLead" "$rigOther" human-owner ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf '%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## A model call anywhere would reach one of these first, and it only logs.
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
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

## The two threads of every scenario: the session's own, and the one of the session that started it.
rigCurrent="CSESS001:1700000002.000202"
rigParent="CPARENT1:1700000001.000101"
## The header the member send writes, with no row in the names registry: each member by its
## member name, with the default icon of its prefix group.
rigFrom="🤖 *_${rigMember}_* → "
rigToOther="${rigFrom}🤖 *_${rigOther}_*."
rigToLead="${rigFrom}🤖 *_${rigLead}_*."
rigToNobody="${rigFrom}@here."
## Where no member is there to take it -- none named, or none runs in that session -- the human-owner takes it.
rigToOwner="${rigFrom}👤 *_human-owner_* <@URIGOWNER>."

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## The session's spawn records: its own, naming the session that started it, and that
## session's, naming the member it acts as. Each sits in a folder named for neither id.
rigRecords(){ ## parent id in the child's record (none for no parent), owner in the parent's record (empty: the record names none; no-record: the parent has no record), the member the child's record says made the spawn call (optional: a record written before that line has none)
	local spawnDir="$rigScenarioDir/ws/.local/agents/spawned"
	mkdir -p "$spawnDir/child-folder" "$spawnDir/parent-folder"
	## The parent's id names its run and the session it founded alike.
	local childSession=""
	[ "$1" = none ] || childSession="parent-session-id: $1"$'\n'
	printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: %s\n%s%sparent-thread: %s\nowner: %s\n---\n\nparent-member: rig-body-line\n' "$1" "$childSession" "${3:+parent-member: $3
}" "$rigParent" "$rigMember" > "$spawnDir/child-folder/rig-child-id.md"
	## A parent with no record of its own is a native session: its thread is the one recorded for that session.
	if [ "${2:-}" = "no-record" ] ; then
		mkdir -p "$rigScenarioDir/ws/.local/agents/sessions/rig-parent-id" && printf '%s\n' "$rigParent" > "$rigScenarioDir/ws/.local/agents/sessions/rig-parent-id/session.thread"
		return 0
	fi
	printf -- '---\nsession-id: rig-parent-id\nspawn-id: rig-parent-id\nparent-spawn-id: none\nstatus: spawn-started\n%ssession-thread: %s\n---\n\nowner: rig-body-line\n' "${2:+owner: $2
}" "$rigParent" > "$spawnDir/parent-folder/rig-parent-id.md"
}
## One scenario with the usual records: a caller the records name.
rigScene(){ ## scenario directory name
	rigStart "$1"
	rigRecords rig-parent-id "$rigLead"
}
## One served call of a harness tool, as the spawned session of the posting member.
rigCall(){ ## tool name, arguments JSON
	( cd "$rigScenarioDir/ws" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SESSION_ID \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		MDAT_SESSION_THREAD="$rigCurrent" MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool "$1" > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err" )
}
rigRow(){ ## scenario name, tool, arguments JSON
	rigScene "$1"
	rigCall "$2" "$3"
}
rigPosts(){
	ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' '
}
rigFirst(){
	LC_ALL=C sed -n '1p' "$rigScenarioDir/tool.out"
}
## The header of a post: the first line of its text, as the member send wrote it.
rigHeader(){ ## post number (default 1)
	LC_ALL=C awk -v path=text -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" < "$rigScenarioDir/post.${1:-1}" 2>/dev/null | LC_ALL=C sed -n '1p'
}
rigPostedTo(){ ## thread as <channel>:<ts> -- the first post went into it
	LC_ALL=C grep -q -F -- "\"channel\":\"${1%%:*}\"" "$rigScenarioDir/post.1" 2>/dev/null && LC_ALL=C grep -q -F -- "\"thread_ts\":\"${1#*:}\"" "$rigScenarioDir/post.1" 2>/dev/null && printf yes || printf no
}
## The five posting tools, each with the arguments it cannot go without, less `to` and `address_to`.
rigTools='SendMessage="message":"m"
SubagentHandback="outcome":"x"
ReportFindings="subject":"s","findings":"f"
PushNotification="severity":"info","headline":"h"
Artifact="url":"https://x/y"'

[ "$( LC_ALL=C grep -c -F '"name":"SendMessage"' "$rigWire" )" = 1 ] || rigRefuse "the wire adapter declares no SendMessage, so nothing here would be measured"

echo "-- every posting tool declares address_to, and the MCP mirror serves it --"
rigMirror="$( MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigHere/AgentsHarnessMcpMirror.sh" 2>/dev/null )"
while IFS= read -r rigPair ; do
	rigAssert "${rigPair%%=*} declares it" \
		"$( LC_ALL=C grep -F "{\"type\":\"function\",\"function\":{\"name\":\"${rigPair%%=*}\"," "$rigWire" | LC_ALL=C grep -c -F '"address_to":{"type":"string","description":"Optional. ' )" 1
done <<< "$rigTools"
rigAssert "the mirror serves it for each of the five, and for the five that ask" "$( printf '%s\n' "$rigMirror" | LC_ALL=C grep -o -F '"address_to":{"type":"string"' | wc -l | tr -d ' ' )" 10
rigAssert "SendMessage says how a dismissal is sent" \
	"$( LC_ALL=C grep -F '"name":"SendMessage",' "$rigWire" | LC_ALL=C grep -c -F 'send the one word DISMISSED to its session thread, with address_to naming that member. Sent with no address_to, DISMISSED dismisses no one.' )" 1
rigAssert "and so does its address_to" \
	"$( LC_ALL=C grep -F '"name":"SendMessage",' "$rigWire" | LC_ALL=C grep -c -F 'A message DISMISSED dismisses the member named here.' )" 1

echo "-- address_to names the addressee in the header, for each of the five --"
while IFS= read -r rigPair ; do
	rigRow "named${rigPair%%=*}" "${rigPair%%=*}" "{\"to\":\"session-current\",\"address_to\":\"$rigOther\",${rigPair#*=}}"
	rigAssert "${rigPair%%=*}: one post, in the thread named, headed to the member named" "$( rigPosts )$( rigPostedTo "$rigCurrent" ):$( rigHeader )" "1yes:$rigToOther"
done <<< "$rigTools"

echo "-- with no address_to the post is as it always was, and is not refused --"
while IFS= read -r rigPair ; do
	rigStart "bare${rigPair%%=*}"
	rigRecords none ""
	rigCall "${rigPair%%=*}" "{\"to\":\"session-current\",${rigPair#*=}}"
	rigAssert "${rigPair%%=*}: one post, in the thread named, headed @here" "$( rigPosts )$( rigPostedTo "$rigCurrent" ):$( rigHeader )" "1yes:$rigToNobody"
done <<< "$rigTools"

echo "-- it is resolved by the code that resolves it for a question, and shown the same way --"
rigRow askOwner AskQuestion "{\"to\":\"session-current\",\"address_to\":\"human-owner\",\"question\":\"May the rig go on?\",\"wait\":false}"
rigAskHeader="$( rigHeader )"
[ -n "$rigAskHeader" ] || rigRefuse "the question was not posted, so there is no header to compare with: $( rigFirst )"
rigRow sendOwner SendMessage '{"to":"session-current","address_to":"human-owner","message":"m"}'
rigAssert "the human-owner, in one shape: a message has the header of a question to him" "$( rigHeader )" "$rigAskHeader"
rigAssert "and that shape names him and his account"                 "$( rigHeader )" "${rigFrom}👤 *_human-owner_* <@URIGOWNER>."
rigRow sendSeveral SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigOther $rigLead\",\"message\":\"m\"}"
rigAssert "several, separated by spaces: each named, in the order given" "$( rigHeader )" "${rigFrom}🤖 *_${rigOther}_*; 🤖 *_${rigLead}_*."
rigRow sendAccount SendMessage '{"to":"session-current","address_to":"URIGSOME1","message":"m"}'
rigAssert "a Slack account, by its id"                               "$( rigHeader )" "${rigFrom}<@URIGSOME1>."
rigRow sendUnknown SendMessage '{"to":"session-current","address_to":"rig-nobody","message":"m"}'
rigAssert "a name that is no team member: refused as a question to it is, nothing posted" \
	"$( rigPosts ):$( rigFirst | LC_ALL=C cut -c1-22 ):$( LC_ALL=C grep -c -F -- "--address-to 'rig-nobody': no such team member -- expected $rigTmp/skills/rig-nobody" "$rigScenarioDir/tool.out" )" "0:ERROR: the send failed:1"
rigRow sendResult SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigOther\",\"message\":\"m\"}"
rigAssert "the result still says where it went and names the Wait that follows" \
	"$( rigFirst ):$( LC_ALL=C grep -c '^NEXT: to wait for a reply in its thread, call Wait sources=slack:' "$rigScenarioDir/tool.out" )" \
	"Sent to $rigCurrent (the thread of this session) as $rigMember. What the operation reported follows::1"

echo "-- a handback that names nobody is addressed to the caller the records name --"
rigRow backDefault SubagentHandback '{"outcome":"x"}'
rigAssert "to the thread of the session that started it, headed to the member of that session" "$( rigPosts )$( rigPostedTo "$rigParent" ):$( rigHeader )" "1yes:$rigToLead"
rigRow backCurrent SubagentHandback '{"to":"session-current","outcome":"x"}'
rigAssert "the same in the session's own thread"                     "$( rigPosts )$( rigPostedTo "$rigCurrent" ):$( rigHeader )" "1yes:$rigToLead"
rigRow backNamed SubagentHandback "{\"address_to\":\"$rigOther\",\"outcome\":\"x\"}"
rigAssert "an address_to given wins over the caller"                 "$( rigPosts ):$( rigHeader )" "1:$rigToOther"
rigRow backElsewhere SubagentHandback '{"to":"CELSE0001","outcome":"x"}'
rigAssert "into a conversation named by the call: as it always was"  "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"

echo "-- and to nobody where they name none: the handback is posted all the same --"
rigStart backNoParent
rigRecords none "$rigLead"
rigCall SubagentHandback '{"to":"session-current","outcome":"x"}'
rigAssert "no parent session recorded"                               "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"
rigStart backNoRecord
rigRecords rig-parent-id no-record
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a parent with no record of its own, a session never spawned, and no member named: nobody is there to take it, so the human-owner" "$( rigPosts )$( rigPostedTo "$rigParent" ):$( rigHeader )" "1no:$rigToOwner"
rigStart backNoOwner
rigRecords rig-parent-id ""
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a parent record that names no member, a body line never read as one: nobody is there, so the human-owner" "$( rigPosts ):$( rigHeader )" "1:$rigToOwner"
rigStart backSelf
rigRecords rig-parent-id "$rigMember"
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a caller that is the member itself is not addressed to itself" "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"
rigStart backGone
rigRecords rig-parent-id rig-gone
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a caller that is no team member here: nobody named, never a failed handback" "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"
rigStart backOdd
rigRecords rig-parent-id '../rig-lead'
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a caller that is no bare name: no member to take it, so the human-owner, never a failed handback" "$( rigPosts ):$( rigHeader )" "1:$rigToOwner"
rigStart backDots
rigRecords rig-parent-id '..'
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "nor one that names a folder and no member: the human-owner"                "$( rigPosts ):$( rigHeader )" "1:$rigToOwner"

echo "-- the member that made the spawn call, as the session's own spawn record names it --"
rigStart calledNative
rigRecords rig-parent-id no-record "$rigLead"
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "started from a session with no record of its own: addressed to the member its record names" "$( rigPosts )$( rigPostedTo "$rigParent" ):$( rigHeader )" "1yes:$rigToLead"
rigCall SubagentHandback '{"to":"session-current","outcome":"x"}'
rigAssert "the same in the session's own thread"                     "$( rigPosts ):$( rigHeader 2 )" "2:$rigToLead"
rigStart calledWins
rigRecords rig-parent-id "$rigOther" "$rigLead"
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "the member the spawn recorded comes first where it runs in that session; it does not, so the session's executor takes it" "$( rigPosts ):$( rigHeader )" "1:$rigToOther"
rigStart calledNamed
rigRecords rig-parent-id no-record "$rigLead"
rigCall SubagentHandback "{\"address_to\":\"$rigOther\",\"outcome\":\"x\"}"
rigAssert "an address_to given still wins"                           "$( rigPosts ):$( rigHeader )" "1:$rigToOther"
rigStart calledSelf
rigRecords rig-parent-id "$rigLead" "$rigMember"
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a record that names the member itself: never itself, so the session's executor" "$( rigPosts ):$( rigHeader )" "1:$rigToLead"
rigStart calledGone
rigRecords rig-parent-id no-record rig-gone
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a record that names no team member here: nobody named, never a failed handback" "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"
rigStart calledBody
rigRecords rig-parent-id no-record ""
rigCall SubagentHandback '{"outcome":"x"}'
rigAssert "a record written before that line, its parent with no record: no member named, so the human-owner; a body line never read as one" "$( rigPosts ):$( rigHeader )" "1:$rigToOwner"

echo "-- a word is an account or a conversation only by the whole shape of a Slack id --"
rigRow shapeAccount SendMessage '{"to":"session-current","address_to":"URIGSOME1","message":"m"}'
rigAssert "an account: U, then upper-case letters and digits, nine characters in all" "$( rigPosts ):$( rigHeader )" "1:${rigFrom}<@URIGSOME1>."
rigRow shapeAccountLong SendMessage '{"to":"session-current","address_to":"U0RIGSOME11","message":"m"}'
rigAssert "an account of eleven characters"                          "$( rigPosts ):$( rigHeader )" "1:${rigFrom}<@U0RIGSOME11>."
rigRow shapePlace SendMessage '{"to":"session-current","address_to":"CRIGSOME1","message":"m"}'
rigAssert "a conversation: C, D or G the same way"                   "$( rigPosts ):$( rigHeader )" "1:${rigFrom}<#CRIGSOME1>."
rigRow shapeBoth SendMessage "{\"to\":\"session-current\",\"address_to\":\"URIGSOME1 $rigOther DRIGSOME1\",\"message\":\"m\"}"
rigAssert "an account, a member and a conversation, each named as what it is" "$( rigPosts ):$( rigHeader )" "1:${rigFrom}<@URIGSOME1>; 🤖 *_${rigOther}_*; <#DRIGSOME1>."
## What the member send says of a word that names nobody: one line, whole.
rigRefusal(){ ## the word as it was given
	LC_ALL=C grep -c -x -F -- "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: --address-to '$1': no such team member -- expected $rigTmp/skills/$1. The word is no Slack id either: an account is U and a conversation C, D or G, then upper-case letters and digits only, nine characters or more in all. Nothing was sent." "$rigScenarioDir/tool.out"
}
rigShapeNo=0
while IFS= read -r rigWord ; do
	rigShapeNo=$(( rigShapeNo + 1 ))
	rigRow "shapeNot$rigShapeNo" SendMessage "{\"to\":\"session-current\",\"address_to\":\"$( printf '%s' "$rigWord" | LC_ALL=C sed 's/\\/\\\\/g;s/"/\\"/g' )\",\"message\":\"m\"}"
	rigAssert "no id, and no member: $rigWord -- nothing posted, refused in the one line" "$( rigPosts ):$( rigFirst | LC_ALL=C cut -c1-22 ):$( rigRefusal "$rigWord" ):$( LC_ALL=C grep -c -e 'ASSERT' -e 'must be a bare name' "$rigScenarioDir/tool.out" )" "0:ERROR: the send failed:1:0"
done <<'RIG_WORDS'
URIGSOME1.x
URIGSOME1","x":"y
URIGSOME1>.*_rig-other_*
Urigsome1
URIGSOM
CEO
DRIG-SOME1
rig-nobody
Rig.Lead
RIG_WORDS
rigRow shapeMail SendMessage '{"to":"session-current","address_to":"someone@example.invalid","message":"m"}'
rigAssert "control: an email address keeps its own refusal"         "$( rigPosts ):$( LC_ALL=C grep -c -F -- "--address-to 'someone@example.invalid': an email addressee is a declared direction that is not built yet." "$rigScenarioDir/tool.out" )" "0:1"
rigStart shapeParty
rigRecords none ""
rigCall SendMessage '{"to":"human-owner","message":"m","as_bot":true}'
rigAssert "control: the other party of a direct message, an id the send read itself, is named as it came" "$( rigPosts ):$( rigHeader )" "1:${rigFrom}<@URIGOWNER>."
rigStart shapeTarget
rigRecords none ""
rigCall SendMessage '{"to":"URIGSOME1.x:1700000001.000101","message":"m","as_bot":true}'
rigAssert "a place that only begins like an account names no addressee, and nothing is posted there" "$( rigPosts )" 0

for rigPair in 'ReportFindings={"to":"session-current","subject":"s","findings":"f"}' 'SendMessage={"to":"session-current","message":"m"}' ; do
	rigRow "callerNot${rigPair%%=*}" "${rigPair%%=*}" "${rigPair#*=}"
	rigAssert "control: the caller is the default of a handback only, never of ${rigPair%%=*}" "$( rigPosts ):$( rigHeader )" "1:$rigToNobody"
done

## The posts of a scenario as Slack returns them from the thread, each with the text and the
## sender metadata its own payload carries, rendered by the one formatter every reader of a
## thread uses and judged by the one dismissal rule the Wait uses.
rigDismissed(){ ## member -- yes when the rendered thread dismisses it
	local dismissPost dismissList="" dismissNo=0
	for dismissPost in "$rigScenarioDir"/post.* ; do
		[ -f "$dismissPost" ] || continue
		dismissNo=$(( dismissNo + 1 ))
		dismissList="$dismissList${dismissList:+,}{\"ts\":\"1700000009.00000$dismissNo\",\"user\":\"URIGBOT01\",\"text\":$( LC_ALL=C awk -v path=text -v mode=raw -f "$rigHere/AgentsHarnessJsonField.awk" < "$dismissPost" ),\"metadata\":$( LC_ALL=C awk -v path=metadata -v mode=raw -f "$rigHere/AgentsHarnessJsonField.awk" < "$dismissPost" )}"
	done
	printf '{"ok":true,"messages":[%s]}\n' "$dismissList" | LC_ALL=C awk -f "$rigHere/AgentsSlackMessagesFormat.awk" > "$rigScenarioDir/thread.fmt" 2> "$rigScenarioDir/thread.err" || { printf 'unreadable' ; return 0 ; }
	[ "$( LC_ALL=C grep -c '^[0-9]*\.[0-9]* | ' "$rigScenarioDir/thread.fmt" )" = "$dismissNo" ] || { printf 'misrendered' ; return 0 ; }
	dismissalMember="$1" LC_ALL=C awk -f "$rigHere/AgentsDismissalMatch.awk" -f "$rigHere/AgentsHarnessWaitDismissed.awk" "$rigScenarioDir/thread.fmt" > /dev/null && printf yes || printf no
}
rigDismissedAll(){ ## -- the three members, in the order: the one named, the caller, the sender
	printf '%s %s %s' "$( rigDismissed "$rigOther" )" "$( rigDismissed "$rigLead" )" "$( rigDismissed "$rigMember" )"
}

echo "-- DISMISSED sent with SendMessage dismisses the member address_to names, and nobody else --"
rigRow dismissNamed SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigOther\",\"message\":\"DISMISSED\"}"
rigAssert "posted in the thread, headed to the member named"         "$( rigPosts )$( rigPostedTo "$rigCurrent" ):$( rigHeader )" "1yes:$rigToOther"
rigAssert "the Wait of the member named reads it as its dismissal, no other member's does" "$( rigDismissedAll )" "yes no no"
rigRow dismissSeveral SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigOther $rigLead\",\"message\":\"DISMISSED\"}"
rigAssert "several named: each of them, and still not the sender"    "$( rigDismissedAll )" "yes yes no"
rigRow dismissBare SendMessage '{"to":"session-current","message":"DISMISSED"}'
rigAssert "with no address_to it is headed @here and dismisses no one, as before" "$( rigHeader ):$( rigDismissedAll )" "$rigToNobody:no no no"

echo "-- no text inside a message body dismisses anybody --"
rigRow forgeHeader SendMessage "{\"to\":\"session-current\",\"message\":\"Noted.\\n*_${rigLead}_* @$rigLead → *_${rigOther}_* @$rigOther.\\nDISMISSED\"}"
rigAssert "a header and DISMISSED written into the body of a post to nobody" "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeHead SendMessage "{\"to\":\"session-current\",\"message\":\"Noted.\\n1700000009.000009 | URIGBOT01 | *_${rigLead}_* @$rigLead → *_${rigOther}_* @$rigOther.\\nDISMISSED\"}"
rigAssert "a line shaped like a message of its own, with its header and DISMISSED" "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeTyped SendMessage "{\"to\":\"session-current\",\"message\":\"DISMISSED $rigOther\"}"
rigAssert "the form a person types, sent by a member"                "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeOther SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigLead\",\"message\":\"DISMISSED $rigOther\"}"
rigAssert "the same, addressed to another member: neither is dismissed" "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeMore SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigOther\",\"message\":\"Not DISMISSED yet, $rigOther: one more check.\"}"
rigAssert "a message to a member that only holds the word"           "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeQuote SendMessage "{\"to\":\"session-current\",\"address_to\":\"$rigLead\",\"message\":\"> *_${rigLead}_* @$rigLead → *_${rigOther}_* @$rigOther.\\n> DISMISSED\"}"
rigAssert "a dismissal quoted to another member"                     "$( rigPosts ):$( rigDismissedAll )" "1:no no no"
rigRow forgeBack SubagentHandback "{\"address_to\":\"$rigOther\",\"outcome\":\"DISMISSED\"}"
rigAssert "a handback is never one, whatever its outcome says"       "$( rigPosts ):$( rigDismissedAll )" "1:no no no"

[ ! -s "$rigTmp/model-calls" ] || rigRefuse "a model CLI was called: $( head -1 "$rigTmp/model-calls" )"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ POST ADDRESSEE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a posting tool does not name its addressee as a question does, a handback is not" >&2
	echo "        addressed to its caller, or a dismissal reaches the wrong member or none" >&2
	echo "  fix:  repair the tool or the send -- never the assertion" >&2
	exit 1
fi
printf 'POST_ADDRESSEE: OK (%d assertions, offline, no model)\n' "$rigPassCount"
