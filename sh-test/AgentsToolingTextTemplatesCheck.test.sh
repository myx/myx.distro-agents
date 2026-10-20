#!/usr/bin/env bash
## Behavioural check that the texts the tooling posts on its own are blocks of its templates
## (sh-lib/templates/), filled by the one filler, and not texts written in code: the joined
## line of a session, the two lines that say how a run ended (no handback, a question of its
## own open), the readback note, the withdrawn note, the reminder line, the line a
## forwarded request opens with, the line that hands a request to a holder, and the bodies of
## the four report tools (SubagentHandback, ReportFindings, PushNotification, Artifact).
## Three ways. Each block, filled, gives the words it is meant to give. No line of code
## holds one of those texts. And through the tools and operations themselves, run from a
## copy of the package whose two templates carry a mark on every block: what is posted
## carries the mark, so the words posted are the template's and an edit of the template is
## what changes them. The report tools are also run from the package as it is, and post what
## they always posted. The line to a holder is run through its operation by
## AgentsPermissionHoldsCheck and AgentsEscalationOneReplyCheck, which need a session with a
## live holder. Offline: a Slack-shaped fake curl, first on PATH, answers every request.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTest="$rigPackage/sh-test"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/harness/AgentsUniversalHarness.sh" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHere/harness/AgentsUniversalHarness.sh"
for rigNeed in "$rigMember" magic-coordinator keeper-myx ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

mkdir -p "$MMDAPP/.local/temp" || exit 1
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsToolingTextTemplatesCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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

echo "-- each text is a block of a template: filled, it gives its words --"
## One block filled straight from its template, as the tooling fills it.
rigBlock(){ ## template, block `<Section>/<heading>` -- the slots come from the caller's environment
	ASKP_WANT=block ASKP_BLOCK="$2" ASKP_FORM="" LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigHere/questions/AgentsAskPostFill.awk" "$rigHere/templates/$1" 2>&1
}
rigNote="tooling-note.post.format.md"
rigReport="report.post.format.md"
rigAssert "the joined line, with what the member was brought in for" \
	"$( ASKP_F_member=keeper-rig ASKP_F_description='look at the logs' rigBlock "$rigNote" Session/joined )" 'keeper-rig joined: look at the logs'
rigAssert "the joined line, with no description" \
	"$( ASKP_F_member=keeper-rig rigBlock "$rigNote" Session/joined )" 'keeper-rig joined'
rigAssert "the line that says a run ended with no handback" \
	"$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d rigBlock "$rigNote" Session/handback-missing )" \
	'📦 keeper-rig ended its run `0a1b2c3d` and posted no handback. What it did is not reported in this thread.'
rigAssert "the line that says a run ended with questions of its own open, with how many" \
	"$( ASKP_F_member=keeper-rig ASKP_F_run=0a1b2c3d ASKP_F_count=2 rigBlock "$rigNote" Session/question-open )" \
	'❓ keeper-rig ended its run `0a1b2c3d` and left questions of its own open: 2. Each one stays open and can still be answered.'
rigAssert "the readback note, with what was understood" \
	"$( ASKP_F_member=keeper-rig ASKP_F_option=beta ASKP_F_text='the later one' rigBlock "$rigNote" Ask/readback )" \
	$'🔁 Readback by keeper-rig: I take your reply to mean `beta` -- the later one\nIf that is wrong, reply here. Your reply is kept on this decision.'
rigAssert "the readback note, with nothing more said" \
	"$( ASKP_F_member=keeper-rig ASKP_F_option=beta rigBlock "$rigNote" Ask/readback )" \
	$'🔁 Readback by keeper-rig: I take your reply to mean `beta`\nIf that is wrong, reply here. Your reply is kept on this decision.'
rigAssert "the withdrawn note" \
	"$( ASKP_F_member=keeper-rig ASKP_F_reason='the rig went on by itself' rigBlock "$rigNote" Ask/withdrawn )" \
	$'Withdrawn by keeper-rig: the rig went on by itself\nThis question no longer needs an answer.'
rigAssert "the reminder line, with the question quoted under it" \
	"$( ASKP_F_asked='2026-09-29 12:00' ASKP_F_number=2 ASKP_F_question=$'> May the rig?\n> Its second line.' rigBlock "$rigNote" Ask/reminder )" \
	$'⏰ Still waiting for your answer (asked 2026-09-29 12:00, reminder 2):\n> May the rig?\n> Its second line.'
rigAssert "the reminder line, with no question to quote: no empty line under it" \
	"$( ASKP_F_asked="$( rigBlock "$rigNote" Words/asked-earlier )" ASKP_F_number=1 rigBlock "$rigNote" Ask/reminder )" \
	'⏰ Still waiting for your answer (asked an earlier date, reminder 1):'
rigAssert "the line a forwarded request opens with: no request id in it" \
	"$( ASKP_F_by=keeper-rig rigBlock "$rigNote" Ask/forwarded )" \
	'Forwarded by keeper-rig. The answer in this thread is the verdict for this request.'
rigAssert "the same, for a request that goes up because an answer was not applied: why, the target by its place" \
	"$( ASKP_F_by=keeper-rig ASKP_F_reason="$( ASKP_F_by=keeper-rig ASKP_F_tool=Edit ASKP_F_target='rig-place:a/b.md' rigBlock "$rigNote" Reasons/not-held )" rigBlock "$rigNote" Ask/forwarded )" \
	'Forwarded by keeper-rig. The answer in this thread is the verdict for this request. keeper-rig does not hold Edit on `rig-place:a/b.md`, so that answer is not applied.'
rigAssert "the line that hands a request to a holder: the holder named by the addressee field, the request id at the end, never at the head" \
	"$( ASKP_F_member=keeper-rig ASKP_F_address_to=keeper-holder ASKP_F_reason='keeper-other does not hold WebSearch' ASKP_F_request_id=11111111-2222 rigBlock "$rigNote" Ask/now-yours )" \
	'A permission request asked by keeper-rig is now yours to answer, keeper-holder. keeper-other does not hold WebSearch, so that answer is not applied. Answer it with the escalation answer operation, naming request `11111111-2222`.'
rigAssert "what was not held, for a call with no target" \
	"$( ASKP_F_by=keeper-other ASKP_F_tool=WebSearch rigBlock "$rigNote" Reasons/not-held )" 'keeper-other does not hold WebSearch'
## The texts the contacts subsystem prints where a contact is used (F7.10): the two scenarios and the question to the human-owner.
rigAssert "the way to ask the human-owner about a contact: the refusal, the contact by name, the one call of the escalation path, what his answer opens" \
	"$( ASKP_F_member=client-ndm ASKP_F_id=alice-one ASKP_F_name='Alice One' ASKP_F_asked='Alice wants a job.' ASKP_F_refusal=refusal-1 ASKP_F_session=sess-1 rigBlock "$rigNote" Contacts/escalation-ask )" \
	$'The refusal refusal-1 is recorded for the contact alice-one (Alice One), in session sess-1. Ask the human-owner with `RequestPermission refusal_id=refusal-1 reason="client-ndm asks about the contact alice-one: Alice wants a job." task_ref=<the task this serves>`.\nHis click or word opens the grant: for this session, or, with 👤, for the contact whatever the session.'
rigAssert "the same, for a contact with no name: the parenthesis goes with it" \
	"$( ASKP_F_member=client-ndm ASKP_F_id=alice-one ASKP_F_asked='Alice wants a job.' ASKP_F_refusal=refusal-1 ASKP_F_session=sess-1 rigBlock "$rigNote" Contacts/escalation-ask | head -1 )" \
	$'The refusal refusal-1 is recorded for the contact alice-one, in session sess-1. Ask the human-owner with `RequestPermission refusal_id=refusal-1 reason="client-ndm asks about the contact alice-one: Alice wants a job." task_ref=<the task this serves>`.'
rigAssert "being contacted by a sender nobody recorded: said so, with the next step" \
	"$( ASKP_F_value=UX rigBlock "$rigNote" Contacts/contacted-unknown | head -1 )" \
	'No contact is recorded for UX. It is met at Ingest and Basic only: read the request, answer what needs no record, commit nothing.'
rigAssert "being contacted by a recorded sender: the access first, the tiers, the calls to make (three lines hold the four)" \
	"$( ASKP_F_id=alice-one ASKP_F_access='dispatch on job-18 (allowed by human-owner)' rigBlock "$rigNote" Contacts/contacted-known | LC_ALL=C grep -c -F -e 'Access of alice-one: dispatch on job-18 (allowed by human-owner)' -e 'Ingest, always: read and understand it.' -e '--contact-access alice-one --tool <tool> --target <target>' -e '--escalate-contact alice-one' )" 3
rigAssert "reaching a contact, every part given: the contact, how to meet it, a send line for each channel" \
	"$( ASKP_F_id=alice-one ASKP_F_name='Alice One' ASKP_F_organisation=ndm ASKP_F_how='short messages' ASKP_F_slack='conversations c' ASKP_F_email='a@b.c' rigBlock "$rigNote" Contacts/reaching )" \
	$'Reach alice-one, Alice One of ndm. How to meet them: short messages.\nSlack: conversations c. Send with `DistroAgentsTools.fn.sh --member-comms-slack-send-message <you> <conversation> <text>`.\nE-mail: a@b.c. Send with `DistroAgentsTools.fn.sh --member-comms-email-send <you> <address> -- <subject> -- <body>`.\nA send to an address that is no coordinate of a contact you hold is refused. Record what an exchange brings with `DistroAgentsContacts.fn.sh --collect-contact`.'
rigAssert "reaching a contact that has only a name: no organisation, no how-to, no Slack, no e-mail line" \
	"$( ASKP_F_id=alice-one ASKP_F_name='Alice One' rigBlock "$rigNote" Contacts/reaching )" \
	$'Reach alice-one, Alice One.\nA send to an address that is no coordinate of a contact you hold is refused. Record what an exchange brings with `DistroAgentsContacts.fn.sh --collect-contact`.'
## Each report has the form the ask posts have: a title that says what it is, with its icon,
## the task in words where one is known, then each field under a label of its own.
rigHandbackFull=$'# 🏁 Handback\n\n**🗂 Task**\nT\n\n**📦 Outcome**\nO\n\n**🔍 Findings**\nF\n\n**⏳ Unfinished, and what was not checked**\nU\n\n**📬 Answers collected, and questions still open**\nC'
rigAssert "a handback, every field given" \
	"$( ASKP_F_task=T ASKP_F_outcome=O ASKP_F_findings=F ASKP_F_unfinished=U ASKP_F_collected=C rigBlock "$rigReport" Skeleton/SubagentHandback )" "$rigHandbackFull"
rigAssert "a handback with its outcome alone: no label over nothing" \
	"$( ASKP_F_outcome=O rigBlock "$rigReport" Skeleton/SubagentHandback )" $'# 🏁 Handback\n\n**📦 Outcome**\nO'
rigAssert "findings, every field given" \
	"$( ASKP_F_task=T ASKP_F_subject=S ASKP_F_findings=F ASKP_F_evidence=E ASKP_F_confidence=C rigBlock "$rigReport" Skeleton/ReportFindings )" \
	$'# 🔍 Findings\n\nS\n\n**🗂 Task**\nT\n\n**📌 What was established**\nF\n\n**📎 Evidence**\nE\n\n**⚖️ Confidence, and what was not checked**\nC'
rigAssert "a notification: its title the template's own, by its severity, then its headline, its task and its fields" \
	"$( ASKP_F_task=T ASKP_F_severity="$( rigBlock "$rigReport" Severity/alert )" ASKP_F_headline=H ASKP_F_detail=D ASKP_F_action_required=A rigBlock "$rigReport" Skeleton/PushNotification )" \
	$'# 🚨 Alert\n\nH\n\n**🗂 Task**\nT\n\n**📋 Detail**\nD\n\n**👉 What you need to do**\nA'
rigAssert "a notification with its headline alone: the title and the headline, no label" \
	"$( ASKP_F_severity="$( rigBlock "$rigReport" Severity/info )" ASKP_F_headline=H rigBlock "$rigReport" Skeleton/PushNotification )" $'# ℹ️ Notice\n\nH'
rigAssert "the three titles of a notification" "$( rigBlock "$rigReport" Severity/info )|$( rigBlock "$rigReport" Severity/warn )|$( rigBlock "$rigReport" Severity/alert )" "ℹ️ Notice|⚠️ Warning|🚨 Alert"
rigAssert "a document announced, with no title given: the word for one is its title" \
	"$( ASKP_F_title="$( rigBlock "$rigReport" Words/untitled )" ASKP_F_kind=proposal ASKP_F_url=https://rig.invalid/d ASKP_F_summary=S rigBlock "$rigReport" Skeleton/Artifact )" \
	$'# 📘 Document\n\n**🏷 Kind**\nproposal\n\n**🔗 Link**\nhttps://rig.invalid/d\n\n**📝 Summary**\nS'
rigAssert "the task of a report: the task in words leads, the names of its item follow the words" \
	"$( ASKP_F_task_title='Rework the rig widget' ASKP_F_task_names='`task-rig` · `dispatch-rig`' rigBlock "$rigReport" Lines/task )" 'Rework the rig widget · `task-rig` · `dispatch-rig`'
rigAssert "with the task as a handback gives it: on a line of its own under them" \
	"$( ASKP_F_task_title='Rework the rig widget' ASKP_F_task_names='`task-rig`' ASKP_F_task_given='Check the rig.' rigBlock "$rigReport" Lines/task )" $'Rework the rig widget · `task-rig`\nCheck the rig.'
rigAssert "no report block starts a line with a slot that holds an identifier" \
	"$( LC_ALL=C awk '/^# Skeleton/ { on = 1 } /^# Severity/ { on = 0 } on && /^(\[\[)?`?\{\{(task-names|session-id|request-id|run)\}\}/ { hitCount++ } END { print hitCount + 0 }' "$rigHere/templates/$rigReport" )" 0
rigAssert "a value is placed as it is: a slot mark, a group mark, an ampersand and a backslash in it pass through" \
	"$( ASKP_F_member='k' ASKP_F_reason='a {{slot}} [[group]] & \1 %s' rigBlock "$rigNote" Ask/withdrawn | head -1 )" 'Withdrawn by k: a {{slot}} [[group]] & \1 %s'

echo "-- no line of code holds one of these texts --"
## Each text by words only it has; a comment line is no code.
rigInCode(){ ## fixed text -> how many code lines of the package hold it
	cat "$rigHere"/*/*.sh "$rigHere"/*/*.include "$rigPackage/sh-scripts"/*.sh 2>/dev/null | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- "$1" || :
}
for rigPhrase in ' joined%s' 'posted no handback' 'left questions of its own open' 'Answered by $' 'Readback by $' 'Withdrawn by $' 'is now yours to answer' 'The answer in this thread is the verdict' 'Still waiting for your answer' \
	"'Handback\\n" "'Findings: %s" 'Task as given:' 'What was established' 'Unfinished, and what was not checked' 'Confidence, and what was not checked' 'Action required:' 'What you need to do' 'Answers collected, and questions still open' \
	'It is met at Ingest and Basic only' 'His click or word opens the grant' 'Ingest, always: read and understand it' 'Send with `DistroAgentsTools.fn.sh --member-comms' ; do
	rigAssert "no code line holds: $rigPhrase"                "$( rigInCode "$rigPhrase" )" 0
done
rigAssert "control: the same search does find a text that is written in code" "$( [ "$( rigInCode 'Nothing was sent.' )" -gt 0 ] && printf found || printf blind )" found

## ---- the tools and operations themselves ----
## A copy of the package whose two templates carry a mark at the head of every block, the rest
## of the origin linked: what is posted from there carries the mark only if its words are the
## template's.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents"
for rigEntry in "$MDLT_ORIGIN"/* ; do [ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigOrigin/${rigEntry##*/}" ; done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do [ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}" ; done
for rigEntry in "$rigPackage"/* ; do
	case "${rigEntry##*/}" in
		sh-lib|sh-scripts) ( cd "$rigPackage" && tar cf - "${rigEntry##*/}" ) | ( cd "$rigOrigin/myx/myx.distro-agents" && tar xf - ) || rigRefuse "the package could not be copied for the marked run" ;;
		*) ln -s "$rigEntry" "$rigOrigin/myx/myx.distro-agents/${rigEntry##*/}" ;;
	esac
done
for rigMarked in "$rigNote" "$rigReport" ; do
	LC_ALL=C awk '/^```/ { fence = ! fence ; print ; first = fence ; next ; } first { print "RIGMARK " $0 ; first = 0 ; next ; } { print ; }' "$rigHere/templates/$rigMarked" \
		> "$rigOrigin/myx/myx.distro-agents/sh-lib/templates/$rigMarked" || rigRefuse "the template $rigMarked could not be marked"
done
[ "$( LC_ALL=C grep -c '^RIGMARK ' "$rigOrigin/myx/myx.distro-agents/sh-lib/templates/$rigNote" )" -ge 6 ] || rigRefuse "the marked copy of $rigNote holds no marked block"

rigScenarioDir=""
rigScenarioOrigin=""
rigStart(){ ## scenario directory name, origin (the package as it is, or the marked copy)
	rigScenarioDir="$rigTmp/$1"
	rigScenarioOrigin="$2"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/ws/IN" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
## One served call of a tool, as the member, from the scenario's origin.
rigTool(){ ## tool, argument object
	( cd "$rigScenarioDir/ws" && printf '%s' "$2" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID \
		MDLT_ORIGIN="$rigScenarioOrigin" MDLT_OPTION="--run-from-path $rigScenarioOrigin" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigScenarioOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" --intern-tool "$1" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
}
## One team operation from the scenario's origin: as a member's session where RIG_OP_AGENT names one, else as the console.
RIG_OP_AGENT=""
rigOp(){ ## operation and its arguments
	( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MDLT_ORIGIN="$rigScenarioOrigin" MDLT_OPTION="--run-from-path $rigScenarioOrigin" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		bash "$rigScenarioOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
}
## The body of the scenario's n-th post: the text it carries, as sent, after its author line.
rigBodyOf(){ ## post number
	[ -f "$rigScenarioDir/post.$1" ] || { printf 'no-such-post' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { rest = substr( rest, 1, end - 1 ) ; } headEnd = index( rest, "\\n" ) ; print ( headEnd ? substr( rest, headEnd + 2 ) : rest ) ; exit ; }' "$rigScenarioDir/post.$1"
}
rigPosts(){
	cat "$rigScenarioDir/posts" 2>/dev/null || printf 0
}
## How many posts of the scenario hold a text.
rigSaid(){ ## fixed text
	local saidFile saidCount=0
	for saidFile in "$rigScenarioDir"/post.[0-9]* ; do
		[ -f "$saidFile" ] || continue
		LC_ALL=C grep -q -F -- "$1" "$saidFile" && saidCount=$(( saidCount + 1 ))
	done
	printf '%s' "$saidCount"
}

echo "-- the four report tools, from the package as it is --"
rigStart reports "$MDLT_ORIGIN"
rigTool SubagentHandback '{"to":"magic-team","task":"Check the rig.","outcome":"The rig holds.","findings":"Nothing is loose.","unfinished":"The far side was not checked."}'
[ "$( rigPosts )" = 1 ] || rigRefuse "the handback never reached the fake curl, so nothing below would be measured: $( head -1 "$rigScenarioDir/out" )"
rigAssert "a handback of a session with no item: its title, the task as the call gave it, then each field under its label" "$( rigBodyOf 1 )" \
	'# 🏁 Handback\n\n**🗂 Task**\nCheck the rig.\n\n**📦 Outcome**\nThe rig holds.\n\n**🔍 Findings**\nNothing is loose.\n\n**⏳ Unfinished, and what was not checked**\nThe far side was not checked.'
rigTool ReportFindings '{"to":"magic-team","subject":"the rig","findings":"It holds at 100% load."}'
rigAssert "findings: a field the call left out leaves its label out, no task label where no task is known, and a percent sign is a percent sign" "$( rigBodyOf 2 )" \
	'# 🔍 Findings\n\nthe rig\n\n**📌 What was established**\nIt holds at 100% load.'
rigTool PushNotification '{"to":"magic-team","severity":"warn","headline":"The rig is warm.","action_required":"Look at the fan."}'
rigAssert "a notification: its title by its severity, its headline, the field given" "$( rigBodyOf 3 )" \
	'# ⚠️ Warning\n\nThe rig is warm.\n\n**👉 What you need to do**\nLook at the fan.'
rigAssert "it opens with no word in capitals and no double hyphen, as it did" "$( rigSaid 'WARN -- ' ):$( rigSaid 'Action required:' )" "0:0"
rigTool Artifact '{"to":"magic-team","url":"https://rig.invalid/doc","kind":"proposal","summary":"The rig, on one page."}'
rigAssert "a document announced with no title: the word for one as its title, then its fields" "$( rigBodyOf 4 )" \
	'# 📘 Document\n\n**🏷 Kind**\nproposal\n\n**🔗 Link**\nhttps://rig.invalid/doc\n\n**📝 Summary**\nThe rig, on one page.'
rigTool PushNotification '{"to":"magic-team","severity":"bogus","headline":"The rig."}'
rigAssert "control: a severity that is none is still refused, and nothing more is posted" "$( LC_ALL=C grep -c 'severity must be info, warn or alert' "$rigScenarioDir/out" ):$( rigPosts )" "1:4"

echo "-- a report of a session that works a task says the task in words --"
## The session's spawn was dispatched for a board item: a dispatch that tracks a task.
rigStart reports-task "$MDLT_ORIGIN"
mkdir -p "$rigScenarioDir/data/board/running" "$rigScenarioDir/ws/.local/agents/spawned/rig-report-session"
printf -- '---\ntype: task\nowner: %s\n---\n\n# Rework the rig widget\n\nThe widget drops its last line. Make it keep it.\n' "$rigMember" > "$rigScenarioDir/data/board/running/task-20261012T0000Z-rig-widget.md"
printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: rig-report-session\ntracks: task-20261012T0000Z-rig-widget\n---\n\n# rig dispatch\n' "$rigMember" > "$rigScenarioDir/data/board/running/dispatch-20261012T0100Z-rig-widget.md"
## Its run reports to magic-coordinator, as a start writes it now: the item, which names no
## reviewer, is reviewed there, so no review prompt is posted among the posts counted below.
rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$rigHere/session/AgentsTools.SpawnSandbox.include" )"
[ -n "$rigReportsTo" ] || rigRefuse "the package names no field for where a run reports to (agentsRunRouteField)"
printf -- '---\nsession-id: rig-report-session\nspawn-id: rig-report-session\nparent-spawn-id: none\n%s: magic-coordinator\nowner: %s\nstatus: spawn-started\nspawns: dispatch-20261012T0100Z-rig-widget\n---\n' "$rigReportsTo" "$rigMember" > "$rigScenarioDir/ws/.local/agents/spawned/rig-report-session/rig-report-session.md"
rigTaskTool(){ ## tool, argument object -- one served call of that session
	( cd "$rigScenarioDir/ws" && printf '%s' "$2" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MDLT_ORIGIN="$rigScenarioOrigin" MDLT_OPTION="--run-from-path $rigScenarioOrigin" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID=rig-report-session \
		bash "$rigScenarioOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" --intern-tool "$1" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
}
rigTaskLine='Rework the rig widget · `task-20261012T0000Z-rig-widget` · `dispatch-20261012T0100Z-rig-widget`'
rigTaskTool PushNotification '{"to":"magic-team","severity":"alert","headline":"The rig stopped.","detail":"It stopped at the second step."}'
[ "$( rigPosts )" = 1 ] || rigRefuse "the notification of the session with a task never reached the fake curl: $( head -1 "$rigScenarioDir/out" )"
rigAssert "a notification: its title, its headline, the task in words with the names of its item after the words, then the detail" "$( rigBodyOf 1 )" \
	"# 🚨 Alert\\n\\nThe rig stopped.\\n\\n**🗂 Task**\\n$rigTaskLine\\n\\n**📋 Detail**\\nIt stopped at the second step."
rigTaskTool SubagentHandback '{"to":"magic-team","task":"Check the rig.","outcome":"The rig holds."}'
rigAssert "a handback: the task in words, and under it the task as the call gave it" "$( rigBodyOf 2 )" \
	"# 🏁 Handback\\n\\n**🗂 Task**\\n$rigTaskLine\\nCheck the rig.\\n\\n**📦 Outcome**\\nThe rig holds."
rigTaskTool ReportFindings '{"to":"magic-team","subject":"the rig","findings":"It holds."}'
rigAssert "findings: the same task, under their subject" "$( rigBodyOf 3 )" \
	"# 🔍 Findings\\n\\nthe rig\\n\\n**🗂 Task**\\n$rigTaskLine\\n\\n**📌 What was established**\\nIt holds."
rigTaskTool Artifact '{"to":"magic-team","url":"https://rig.invalid/doc","title":"The rig, measured"}'
rigAssert "a document announced: its own title is the title of the post, then the same task" "$( rigBodyOf 4 )" \
	"# 📘 The rig, measured\\n\\n**🗂 Task**\\n$rigTaskLine\\n\\n**🔗 Link**\\nhttps://rig.invalid/doc"
## An item with no words of its own: a dispatch that tracks nothing and has no heading.
printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: rig-report-session\n---\n' "$rigMember" > "$rigScenarioDir/data/board/running/dispatch-20261012T0100Z-rig-widget.md"
rigTaskTool PushNotification '{"to":"magic-team","severity":"info","headline":"The rig goes on."}'
rigAssert "a task with no words to say it: no Task label, and never the name of its item alone under one" "$( rigBodyOf 5 )" '# ℹ️ Notice\n\nThe rig goes on.'
rigTaskTool SubagentHandback '{"to":"magic-team","task":"Check the rig.","outcome":"The rig holds."}'
rigAssert "a handback there: the task as the call gave it, alone" "$( rigBodyOf 6 )" '# 🏁 Handback\n\n**🗂 Task**\nCheck the rig.\n\n**📦 Outcome**\nThe rig holds.'
rigAssert "no line of these posts starts with the name of an item" \
	"$( for rigPostNo in 1 2 3 4 5 6 ; do rigBodyOf "$rigPostNo" ; printf '\\n' ; done | LC_ALL=C awk '{ lineCount = split( $0, lineOf, /\\n/ ) ; for ( lineNo = 1 ; lineNo <= lineCount ; lineNo++ ) { if ( lineOf[lineNo] ~ /^`?(task|dispatch)-[0-9]/ ) { hitCount++ ; } } } END { print hitCount + 0 ; }' )" 0

echo "-- from the copy with marked templates: what is posted is the template's --"
rigStart reports-marked "$rigOrigin"
rigTool SubagentHandback '{"to":"magic-team","outcome":"The rig holds."}'
[ "$( rigPosts )" = 1 ] || rigRefuse "the handback of the marked run never reached the fake curl: $( head -1 "$rigScenarioDir/out" )"
rigAssert "a handback follows its template"               "$( rigBodyOf 1 )" 'RIGMARK # 🏁 Handback\n\n**📦 Outcome**\nThe rig holds.'
rigTool ReportFindings '{"to":"magic-team","subject":"the rig","findings":"It holds."}'
rigAssert "findings follow their template"                "$( rigBodyOf 2 )" 'RIGMARK # 🔍 Findings\n\nthe rig\n\n**📌 What was established**\nIt holds.'
rigTool PushNotification '{"to":"magic-team","severity":"info","headline":"The rig is fine."}'
rigAssert "a notification follows its template, its title too" "$( rigBodyOf 3 )" 'RIGMARK # RIGMARK ℹ️ Notice\n\nThe rig is fine.'
rigTool Artifact '{"to":"magic-team","url":"https://rig.invalid/doc"}'
rigAssert "a document announced follows its template, the word for no title too" "$( rigBodyOf 4 )" 'RIGMARK # 📘 RIGMARK Document\n\n**🔗 Link**\nhttps://rig.invalid/doc'

## One open question of the member, in a thread of its own, as the ask tools leave it.
rigRecord(){ ## id, kind, address-to, options (may be empty), age in seconds (default 60)
	local recordTs="$(( $( date +%s ) - ${5:-60} )).000100"
	{
		printf -- '---\nstatus: reply-pending\nowner: %s\nhost: rig\n' "$rigMember"
		printf 'communication-channel-id: slack:CRIG00001\nblocked-on: reply from %s\nsession-id: rig-asker\nkind: %s\n' "$3" "$2"
		printf 'address-to: %s\nchannel: CRIG00001\nquestion-ts: %s\nthread-ts: %s\n' "$3" "$recordTs" "$recordTs"
		printf 'addressees: URIGOWNER\nasking-accounts: URIGSELF1\nasked-at: 2026-09-29 12:00 +0300\n'
		printf -- '---\n\n# Question asked\n\n# 🧭 Decision\n\nWhich way should the rig go?\n\n**✅ How to answer**\n- reply in this thread\n'
	} > "$rigScenarioDir/ws/.local/agents/pending/$1.md"
	[ -z "$4" ] || printf '%s\n' "$4" > "$rigScenarioDir/ws/.local/agents/pending/$1.options"
	rigRecordTs="$recordTs"
}
rigStart withdrawn "$rigOrigin"
rigRecord 11111111-0000-0000-0000-000000000001 question human-owner ""
RIG_OP_AGENT="$rigMember" rigOp --member-pending-reply-settle "$rigMember" 11111111-0000-0000-0000-000000000001 --withdraw --reason "the rig went on by itself"
rigAssert "the withdrawn note follows its template"       "$( head -1 "$rigScenarioDir/op.out" ):$( rigBodyOf 1 )" \
	'WITHDRAWN 11111111-0000-0000-0000-000000000001:RIGMARK Withdrawn by magic-tester: the rig went on by itself\nThis question no longer needs an answer.'

rigStart readback "$rigOrigin"
rigRecord 11111111-0000-0000-0000-000000000002 decision human-owner $'- alpha the first way\n- beta the second way'
## The person replied, and the reply names neither option.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"first"},{"ts":"%s","user":"URIGOWNER","text":"the later one, I think","thread_ts":"%s"}],"has_more":false}\n' \
	"$rigRecordTs" "$(( ${rigRecordTs%%.*} + 30 )).000200" "$rigRecordTs" > "$rigScenarioDir/replies.json"
RIG_OP_AGENT="$rigMember" rigOp --member-escalation-readback "$rigMember" 11111111-0000-0000-0000-000000000002 beta "the later one is the second way"
rigAssert "the readback note follows its template"        "$( LC_ALL=C grep -c '^ESCALATION: 11111111-0000-0000-0000-000000000002 answered' "$rigScenarioDir/op.out" ):$( rigBodyOf 1 )" \
	'1:RIGMARK 🔁 Readback by magic-tester: I take your reply to mean `beta` -- the later one is the second way\nIf that is wrong, reply here. Your reply is kept on this decision.'

rigStart forwarded "$rigOrigin"
rigRecord 11111111-0000-0000-0000-000000000003 decision magic-coordinator $'- alpha the first way\n- beta the second way'
rigOp --magic-escalation-forward magic-coordinator 11111111-0000-0000-0000-000000000003
rigAssert "the line a forwarded request opens with follows its template, ahead of the request as its record holds it" \
	"$( LC_ALL=C grep -c '^ESCALATION: 11111111-0000-0000-0000-000000000003 forwarded' "$rigScenarioDir/op.out" ):$( rigBodyOf 1 | LC_ALL=C sed 's/\\n.*$//' ):$( rigSaid 'Which way should the rig go?' )" \
	'1:RIGMARK Forwarded by magic-coordinator. The answer in this thread is the verdict for this request.:1'
rigAssert "and it shows no request id"                    "$( rigSaid '11111111-0000-0000-0000-000000000003' )" 0

rigStart reminder "$rigOrigin"
rigRecord 11111111-0000-0000-0000-000000000004 question human-owner "" $(( 31 * 60 ))
## The reminders are an in-context helper with no operation: run inside the tool's own set-up context.
printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.PendingReplyCollect.include"' \
	'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.PendingReplyRemind.include"' \
	'AgentsToolsPendingReplyRemindRun || exit 1' \
	| ( cd "$rigScenarioDir/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
rigAssert "the reminder line follows its template, the question quoted under it" \
	"$( LC_ALL=C grep -c '^REMINDED 11111111-0000-0000-0000-000000000004 human-owner ' "$rigScenarioDir/op.out" ):$( rigBodyOf 1 | LC_ALL=C sed 's/(asked [^)]*, reminder/(asked WHEN, reminder/' )" \
	'1:RIGMARK ⏰ Still waiting for your answer (asked WHEN, reminder 1):\n> Which way should the rig go?'

rigStart joined "$rigOrigin"
## The console the spawn proxy launches: it records the brief, and runs no model.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigScenarioDir/ws/DistroAgentsConsole.sh"
chmod +x "$rigScenarioDir/ws/DistroAgentsConsole.sh"
( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE \
	CLAUDE_CODE_SESSION_ID=rig-native-one MDAT_SPAWN_AGENT=magic-coordinator MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" \
	bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-agent-spawn-proxy keeper-myx --description "change the loader code" \
		--dispatch-doc:none --wait --context rig-tooling-texts <<< "RIG-BRIEF-MARKER" ) > "$rigScenarioDir/op.out" 2>&1 || :
LC_ALL=C grep -q 'RIG-BRIEF-MARKER' "$rigScenarioDir/brief" 2>/dev/null || rigRefuse "the fake console never received the brief, so the joined line was never due: $( LC_ALL=C grep -m1 ERROR "$rigScenarioDir/op.out" )"
rigAssert "the joined line follows its template, as a reply in the session's thread" \
	"$( LC_ALL=C grep -l -F 'RIGMARK keeper-myx joined: change the loader code' "$rigScenarioDir"/post.[0-9]* 2>/dev/null | LC_ALL=C xargs grep -l -F '"thread_ts"' 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1

rigAssert "no request left this box"                     "$( cat "$rigTmp"/*/curl.log | LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOLING TEXT TEMPLATES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a text the tooling posts is written in code, or its template block no longer gives its words" >&2
	echo "  fix:  put the text in its block of sh-lib/templates/tooling-note.post.format.md or report.post.format.md, and fill it there -- never the assertion" >&2
	exit 1
fi
printf 'TOOLING_TEXT_TEMPLATES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
