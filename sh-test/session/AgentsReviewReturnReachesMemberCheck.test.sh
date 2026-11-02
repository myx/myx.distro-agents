#!/usr/bin/env bash
## Behavioural check on S6.3 of `20261102-refactorings.epic.md`: "A returned review reaches its member
## as plainly its own: addressed to it, naming its item, and saying the work is open again. Today a
## librarian read one as another session's handback and kept waiting."
##
## Held through the REAL send, the REAL read and the REAL drop, never by reading the code:
##   1. the tooling's return post carries the tooling's own mark (`tracking: tooling`) and names the
##      member it is addressed to -- it is a tooling post, and the member is its addressee;
##   2. a member's own render of that conversation keeps its return: the drop does not take it away
##      (this is the row: the mark that says "for this member" survives the rendering);
##   3. the post the member keeps names the item it is about and carries the corrections, both of
##      them, the paragraph break between them included;
##   4. the bound: another member's render drops it, and so does a tooling post addressed to nobody,
##      so what section 2 keeps is kept because it is addressed and not because the drop has stopped
##      dropping;
##   5. the control: a single-paragraph post of the tooling, addressed to the member, is kept -- the
##      machinery of this check keeps a post that is plainly its own, today and after the fix.
##
## WHY THIS IS RED ON THE TREE BEFORE THE FIX: a post of several paragraphs is sent as blocks, its
## `text` only the notification line. The reader renders a tooling post from its block text
## (`AgentsSlackMessagesFormat.awk:405`), and block text carries no `*_<member>_*` mark -- so
## `AgentsToolsTrackingDrop` cannot see who the post is for, reads it as the tooling's post for
## nobody, and takes it out. The member's Wait never shows the return.
##
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigDropInclude="$rigPackage/sh-lib/session/AgentsTools.TrackingDrop.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/session-chat.curl.stub.sh" "$rigDropInclude" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewReturnReachesMemberCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigWs/.local/temp" "$rigWs/.local/agents/spawned" "$rigScn" \
	"$rigTmp/skills/keeper-addr" "$rigTmp/skills/keeper-other"
for rigMember in keeper-addr keeper-other ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env" 2> /dev/null \
	|| { mkdir -p "$rigWs/.local/.agents" ; printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env" ; }
printf 'SLACK_USER_TOKEN=rig-user-token-ADDR\n' > "$rigWs/.local/.agents/keeper-addr.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-OTHER\n' > "$rigWs/.local/.agents/keeper-other.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigTooling(){ ## words... -- one call of the tooling from the rig workspace; stdout is the result
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID -u MDAT_SEND_FLOOR \
		"PATH=$rigTmp/bin:$PATH" "RIG_SCENARIO=$rigScn" "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash "$rigTool" "$@" 2> "$rigScn/last.err" )
}
rigDrop(){ ## member, a rendering file -- what the drop leaves of it for that member
	( cd "$rigWs" && env "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" bash -c '. "$1" ; AgentsToolsTrackingDrop "$2" < "$3"' _ "$rigDropInclude" "$1" "$2" )
}
rigCount(){ ## file, fixed string -- how many of its lines hold the string
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

## The return a review sends: the shape AgentsReviewSendToChild posts, several paragraphs long.
rigItem="dispatch-20261102T1200Z-rig"
{
	printf 'RETURNED for corrections on %s. Continue the same task, then hand back again.\n\n' "${rigItem%.md}"
	printf 'The brief names one file and the fix touches two.\n\n'
	printf 'The second paragraph is the one a block rendering loses.\n'
} > "$rigTmp/return.body"

echo "-- 1. the return is a tooling post, addressed to the member its item belongs to --"
rigTooling --intern-op-comms-slack-send-message keeper-addr "CRIG00002:1792422595.000010" --identity-bot --address-to keeper-addr --from-file "$rigTmp/return.body" > /dev/null
printf 'a single line the control sends @keeper-addr' > "$rigTmp/control.body"
rigTooling --intern-op-comms-slack-send-message keeper-addr "CRIG00002:1792422595.000010" --identity-bot --address-to keeper-addr --from-file "$rigTmp/control.body" > /dev/null
printf 'a note for nobody in particular' | rigTooling --intern-op-comms-slack-send-message keeper-other "CRIG00002:1792422595.000010" --identity-bot --from-stdin > /dev/null
rigAssert "three posts were made"                      "$( ls "$rigScn"/post.* 2> /dev/null | LC_ALL=C grep -c . )" 3
rigAssert "the return carries the tooling's own mark"  "$( rigCount "$rigScn/post.1" '"tracking":"tooling"' )" 1
rigAssert "the return names the member it is addressed to in its own text" \
	"$( rigCount "$rigScn/post.1" '*_keeper-addr_*' )" 1
rigAssert "and names the item it is about"             "$( rigCount "$rigScn/post.1" "$rigItem" )" 1

echo "-- 2. the member's own render keeps its return --"
rigMessage(){ ## ts, post file -- a Slack message made of a payload of a post
	LC_ALL=C sed -e "s/^{\"channel\":\"[A-Z0-9]*\",/{\"ts\":\"$1\",\"user\":\"URIGBOT01\",/" "$2"
}
printf '{"ok":true,"messages":[%s,%s,%s],"has_more":false}\n' \
	"$( rigMessage 1792422595.000100 "$rigScn/post.1" )" \
	"$( rigMessage 1792422595.000200 "$rigScn/post.2" )" \
	"$( rigMessage 1792422595.000300 "$rigScn/post.3" )" > "$rigScn/history.CRIG00002.json"
rigTooling --intern-op-comms-slack-read keeper-addr "CRIG00002" --oldest 1792422000 > "$rigScn/rendered.raw"
LC_ALL=C awk '/^[0-9]+\.[0-9]+ \| / { shown = 1 } shown { print }' "$rigScn/rendered.raw" > "$rigScn/rendered"
rigAssert "the read rendered all three posts"          "$( rigCount "$rigScn/rendered" '[tracking: tooling]' )" 3
rigDrop keeper-addr "$rigScn/rendered" > "$rigScn/for.addr"
rigAssert "for the member it is addressed to, the return stays" "$( rigCount "$rigScn/for.addr" "$rigItem" )" 1
rigAssert "...and so does the single-line control"     "$( rigCount "$rigScn/for.addr" 'single line the control' )" 1

echo "-- 3. what the member keeps names its item and carries the corrections whole --"
rigAssert "the corrections' first paragraph is there"  "$( rigCount "$rigScn/for.addr" 'The brief names one file and the fix touches two.' )" 1
rigAssert "the second paragraph is there too"          "$( rigCount "$rigScn/for.addr" 'The second paragraph is the one a block rendering loses.' )" 1
rigAssert "and the post says the work is open again"   "$( rigCount "$rigScn/for.addr" 'Continue the same task, then hand back again.' )" 1

echo "-- 4. the bound: one for another member, and one for nobody, are still taken out --"
rigDrop keeper-other "$rigScn/rendered" > "$rigScn/for.other"
rigAssert "another member's render drops the return"   "$( rigCount "$rigScn/for.other" "$rigItem" )" 0
rigAssert "and the note addressed to nobody"           "$( rigCount "$rigScn/for.addr" 'note for nobody in particular' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW RETURN REACHES MEMBER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_RETURN_REACHES_MEMBER: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
