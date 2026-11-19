#!/usr/bin/env bash
## Behavioural check on the fill of every permission post kind (sh-lib/templates/request-permission.post.format.md and
## permission-set.post.format.md), through AgentsToolsAskPostFill, the fill the tools use. Offline: nothing is posted.
## Held: a part of the post whose own required slot is empty has no value, so `[[{{allowed}}]]` is left out of an
## ordinary request and kept for an authority request that gives `allowed-words`; every kind fills or skips each slot;
## a required slot left empty is still refused, named by the field the call left empty; an authority request the tooling
## makes keeps `allowed-words` with its slots, so its post filled again keeps its allowed line. That request is made
## offline, in a rig workspace, a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigPackage/sh-lib/questions/AgentsTools.AskPost.include" || rigRefuse "the ask post include is missing: $rigPackage/sh-lib/questions/AgentsTools.AskPost.include"
. "$rigPackage/sh-lib/grants/AgentsTools.PermissionSetPost.include" || rigRefuse "the permission set post include is missing: $rigPackage/sh-lib/grants/AgentsTools.PermissionSetPost.include"
type AgentsToolsAskPostFill > /dev/null 2>&1 || rigRefuse "AgentsToolsAskPostFill is not defined after its include"
type AgentsToolsPermissionSetFill > /dev/null 2>&1 || rigRefuse "AgentsToolsPermissionSetFill is not defined after its include"
for rigName in $( compgen -v ASKP_ ) ; do unset "$rigName" ; done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Whether a fill's output holds one whole line: `yes` or `no`.
rigHasLine(){ ## output, line
	case $'\n'"$1"$'\n' in *$'\n'"$2"$'\n'*) echo yes ;; *) echo no ;; esac
}
## Whether a fill's output holds a text anywhere: `yes` or `no`.
rigHasText(){ ## output, text
	case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac
}
## One permission post filled; prints its output, stderr included, then `rc=<status>` on a line of its own.
rigPost(){ ## want (post|closed), answer form -- the slots come from the caller's environment
	local postOut
	postOut="$( AgentsToolsAskPostFill "$1" request-permission.post.format.md "$2" 2>&1 )"
	printf '%s\nrc=%s' "$postOut" "$?"
}
rigQuestion='Allow **Edit** on `ws-rig:source/rig/x.sh` for **keeper-rig**? An allow grants exactly that, and nothing wider.'
export ASKP_F_refused_tool=Edit ASKP_F_refused_target='ws-rig:source/rig/x.sh' ASKP_F_refused_for=keeper-rig \
	ASKP_F_refusal_id=refusal-rig-1 ASKP_F_reason='the rig edits its own file' ASKP_F_task='task-rig'

echo "-- an ordinary request: no allowed-words, so no allowed line --"
rigOut="$( rigPost post grant )"
rigAssert "the ordinary post is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "its first line is the refused call" "$( rigHasLine "$rigOut" "$rigQuestion" )" yes
rigAssert "it shows no allowed line" "$( rigHasText "$rigOut" 'This allows:' )" no
rigAssert "its last line is the refusal" "$( rigHasLine "$rigOut" '_Refusal:_ `refusal-rig-1`' )" yes
rigOut="$( rigPost closed grant )"
rigAssert "the ordinary post, closed, is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "the closed post has no answer lines" "$( rigHasText "$rigOut" 'How to answer' )" no

echo "-- the folder, the project and the contact answers --"
rigOut="$( ASKP_F_folder='ws-rig:source/rig/**' rigPost post grant )"
rigAssert "the post with the folder is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "it offers the folder" "$( rigHasLine "$rigOut" '- or click 📁 to allow **Edit** on `ws-rig:source/rig/**`, for this session' )" yes
rigOut="$( ASKP_F_folder='ws-rig:source/rig/sub/**' ASKP_F_project='ws-rig:source/rig/**' rigPost post grant )"
rigAssert "the post with the folder and the project is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "it offers the project" "$( rigHasLine "$rigOut" '- or click 🏗️ to allow **Edit** on the project `ws-rig:source/rig/**`, for this session' )" yes
rigOut="$( ASKP_F_refused_tool=SendMessage ASKP_F_refused_target='contact:rig-contact' ASKP_F_contact=rig-contact rigPost post grant )"
rigAssert "the post for a contact is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "it offers the contact" "$( rigHasLine "$rigOut" '- click ❌ to deny, or 🔁 to allow for this session' )" yes

echo "-- an authority request: allowed-words given, so the allowed line is shown --"
rigOut="$( ASKP_F_refused_target='' ASKP_F_allowed_words='end session rig' rigPost post grant )"
rigAssert "the authority post is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "it shows the allowed line" "$( rigHasLine "$rigOut" 'This allows: end session rig.' )" yes
rigOut="$( ASKP_F_refused_target='' ASKP_F_allowed_words='end session rig' ASKP_F_text=yes rigPost post grant )"
rigAssert "the authority post that asks for a text is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigAssert "it takes the text answers" "$( rigHasLine "$rigOut" '- reply with the text to give in its place' )" yes
rigOut="$( ASKP_F_refused_target='' ASKP_F_allowed_words='end session rig' rigPost post confirm )"
rigAssert "the authority confirmation is filled" "$( rigHasLine "$rigOut" rc=0 )" yes
rigOut="$( ASKP_F_refused_target='' rigPost closed grant )"
rigAssert "an authority post filled again from its kept slots, which hold no allowed-words, is filled" "$( rigHasLine "$rigOut" rc=0 )" yes

echo "-- the permission set post --"
rigOut="$( ASKP_F_scope_words='for this session' ASKP_F_asked='- Edit on `ws-rig:source/rig/**`' AgentsToolsPermissionSetFill post 2>&1 )"
rigAssert "the permission set post is filled" "$?" 0
rigAssert "it asks for the set" "$( rigHasLine "$rigOut" 'May the participants have these, for this session?' )" yes

echo "-- an authority request made by the tooling, filled again from the slots it kept --"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig temp fixture is missing from the package: sh-test/check-fixtures/rig-temp.include.sh"
rigTmp="$( rigTempDir AgentsPermissionPostFillCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents"
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_WORKSPACE_DOMAIN=rig.slack.example\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
rigOut="$( cd "$rigTmp/ws" && unset CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_SESSION_ID harnessAgent harnessSessionId \
	&& export PATH="$rigTmp/bin:$PATH" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/ws/DATA" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
	&& [ "$( command -v curl )" = "$rigTmp/bin/curl" ] && agentsAuthorityCallerId=user-rig agentsAuthorityCallerKind=person agentsAuthorityCallerRun=rig-run \
	&& . "$rigPackage/sh-lib/questions/AgentsTools.Authority.include" && AgentsToolsAuthorityRequestOpen enqueue "" human-owner rig-session rig-original 'end session rig' "" end-session 2>&1 )" \
	|| rigRefuse "the rig could not make an authority request: $rigOut"
rigRecord="$rigTmp/ws/.local/questions/$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^PENDING \([^ ]*\).*/\1/p' ).md"
[ -f "$rigRecord" ] && [ -f "${rigRecord%.md}.fields" ] || rigRefuse "the authority request kept no record and slots: $rigOut"
rigAssert "the request was posted with its allowed line" "$( rigHasText "$( cat "$rigTmp/post.1" 2> /dev/null )" 'This allows: end session rig.' )" yes
rigOut="$( MMDAPP="$rigTmp/ws" AgentsToolsAskPostRecordFill closed "$rigRecord" 2>&1 )"
rigAssert "its post filled again from the kept slots is filled" "$?" 0
rigAssert "it keeps its allowed line" "$( rigHasLine "$rigOut" 'This allows: end session rig.' )" yes

echo "-- a required slot left empty is still refused, by the field's own name --"
rigAssert "no refusal id: refused, naming refusal-id" "$( ASKP_F_refusal_id='' rigPost post grant )" \
	$'AgentsAskPostFill.awk: the slot {{refusal-id}} is required and has no value\nrc=4'
rigAssert "no reason: refused, naming reason" "$( ASKP_F_reason='' rigPost post grant )" \
	$'AgentsAskPostFill.awk: the slot {{reason}} is required and has no value\nrc=4'
rigAssert "no refused tool: refused, naming refused-tool" "$( ASKP_F_refused_tool='' rigPost post grant )" \
	$'AgentsAskPostFill.awk: the slot {{refused-tool}} is required and has no value\nrc=4'

if [ "$rigFailCount" -gt 0 ] ; then
	printf 'PERMISSION_POST_FILL: FAIL (%d of %d assertions)\n' "$rigFailCount" $(( rigPassCount + rigFailCount ))
	exit 1
fi
printf 'PERMISSION_POST_FILL: OK (%d assertions, offline)\n' "$rigPassCount"
