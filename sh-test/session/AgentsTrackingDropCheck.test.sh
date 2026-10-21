#!/usr/bin/env bash
## Behavioural check on what the tooling posted itself, and the readers that decide whether something is input (F7.12, the owner's additions of 2026-10-20;
## sh-lib/session/AgentsTools.TrackingDrop.include and AgentsTrackingDrop.awk, the metadata of the send in AgentsTools.MemberCommsSlack.include, the chat file's
## import in AgentsSessionChatImport.awk). Held, run through the real send and the real read against a Slack-shaped fake curl:
##   1. what the tooling sends itself is marked `tracking: tooling` in the post's metadata, and a member's own send is not
##   2. a read of it shows `[tracking: tooling]`; for the member it is addressed to (DISMISSED, `--address-to`) the drop keeps it -- it always reaches that run --
##      and for any other member, and for a post of the tooling that names the member and is not addressed to it, the drop takes it out; a person's message and a
##      member's own send stay; a tracking post of event-track (a start post of a session, naming the member) goes, and so does the hand-back of a run the
##      member launched that reports to nobody, while the hand-back of one that reports to the member stays
##   3. the chat file keeps what is addressed to a run as news (DISMISSED reaches the session's floor), and every other tracking post as history -- there
##      for whoever reads the thread, never new to a floor
## Offline: a Slack-shaped fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTrackingDropCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/spawned" "$rigScn" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-addr" "$rigTmp/skills/keeper-other"
for rigMember in keeper-rig keeper-addr keeper-other ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in RIG ADDR OTHER ; do printf 'SLACK_USER_TOKEN=rig-user-token-%s\n' "$rigMember" > "$rigWs/.local/.agents/keeper-$( printf '%s' "$rigMember" | LC_ALL=C tr 'A-Z' 'a-z' ).agent.env" ; done
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
rigTooling(){ ## words... -- one call of the tooling from the rig workspace, stdin passed on; stdout is the result
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SEND_FLOOR \
		"PATH=$rigTmp/bin:$PATH" "RIG_SCENARIO=$rigScn" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash "$rigTool" "$@" 2> "$rigScn/last.err" )
}
rigDrop(){ ## member, a rendering file -- what the drop leaves of it for that member
	( cd "$rigWs" && env "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.TrackingDrop.include" ; AgentsToolsTrackingDrop "$1" < "$2"' _ "$1" "$2" )
}

echo "-- 1. the tooling's own sends are marked, a member's are not --"
printf 'DISMISSED' | rigTooling --intern-op-comms-slack-send-message keeper-rig magic-team --identity-bot --address-to keeper-addr --from-stdin > /dev/null
printf 'a note naming @keeper-addr and nobody for' | rigTooling --intern-op-comms-slack-send-message keeper-rig magic-team --identity-bot --from-stdin > /dev/null
printf 'a member speaks to @keeper-addr' | rigTooling --slack-send-message keeper-rig magic-team --identity-bot --from-stdin > /dev/null
rigAssert "three posts were made" "$( ls "$rigScn"/post.* 2> /dev/null | LC_ALL=C grep -c . )" "3"
rigAssert "the DISMISSED of the tooling, addressed, and the note of the tooling carry the mark" "$( LC_ALL=C grep -c -F '"tracking":"tooling"' "$rigScn/post.1" ):$( LC_ALL=C grep -c -F '"tracking":"tooling"' "$rigScn/post.2" )" "1:1"
rigAssert "a member's own send does not" "$( LC_ALL=C grep -c -F '"tracking"' "$rigScn/post.3" )" "0"
rigAssert "all three name the sender in the metadata still" "$( LC_ALL=C grep -c -F '"sender":"keeper-rig"' "$rigScn/post.1" "$rigScn/post.2" "$rigScn/post.3" | LC_ALL=C awk -F: '{ n += $2 } END { print n }' )" "3"

echo "-- 2. the readers drop what the tooling posted, and keep what is for the reader --"
rigMessage(){ ## ts, post file -- a Slack message made of a payload of a post: a read of the channel answers it
	LC_ALL=C sed -e "s/^{\"channel\":\"[A-Z0-9]*\",/{\"ts\":\"$1\",\"user\":\"URIGBOT01\",/" "$2"
}
rigPerson(){ ## ts, text
	printf '{"ts":"%s","user":"URIGFRIEND","text":"%s"}' "$1" "$2"
}
rigTracked(){ ## ts, text, kind, session
	printf '{"ts":"%s","user":"URIGBOT01","text":"%s","metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-team","tracking":"%s","session":"%s"}}}' "$1" "$2" "$3" "$4"
}
rigLaunched(){ ## spawn id, launching member, reports-to
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: rig-parent\nparent-member: %s\nstart-context: spawned\nowner: keeper-other\nreports-to: %s\nstatus: spawn-succeeded\n---\n\n# Spawn session: %s\n' "$1" "$1" "$2" "$3" "$1" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigLaunched rig-away keeper-addr none
rigLaunched rig-home keeper-addr keeper-addr
printf '{"ok":true,"messages":[%s,%s,%s,%s,%s,%s,%s,%s],"has_more":false}\n' \
	"$( rigMessage 1792422595.000100 "$rigScn/post.1" )" \
	"$( rigMessage 1792422595.000200 "$rigScn/post.2" )" \
	"$( rigMessage 1792422595.000300 "$rigScn/post.3" )" \
	"$( rigPerson 1792422595.000400 'RIG-PERSON hello @keeper-addr' )" \
	"$( rigTracked 1792422595.000500 'RIG-START session started by @keeper-addr' session-root rig-away )" \
	"$( rigTracked 1792422595.000600 'RIG-HAND-AWAY done @keeper-addr' handback rig-away )" \
	"$( rigTracked 1792422595.000700 'RIG-HAND-HOME done @keeper-addr' handback rig-home )" \
	"$( rigTracked 1792422595.000800 'RIG-ACTIVITY of a run @keeper-addr' activity rig-home )" > "$rigScn/history-body"
rigTooling --intern-op-comms-slack-read keeper-addr magic-team --oldest 1792422000 > "$rigScn/rendered.raw"
LC_ALL=C awk '/^[0-9]+\.[0-9]+ \| / { shown = 1 } shown { print }' "$rigScn/rendered.raw" > "$rigScn/rendered"
rigAssert "the read shows the marks: [tracking: tooling] on two posts, [tracking: ...] and [session: ...] on the event-track ones" "$( LC_ALL=C grep -c -F '[tracking: tooling]' "$rigScn/rendered" ):$( LC_ALL=C grep -c -F '[session: rig-away]' "$rigScn/rendered" )" "2:2"
rigDrop keeper-addr "$rigScn/rendered" > "$rigScn/for.addr"
rigAssert "for keeper-addr, who the DISMISSED is addressed to: it stays" "$( LC_ALL=C grep -c 'DISMISSED' "$rigScn/for.addr" )" "1"
rigAssert "...and the note of the tooling that only names it, the start post, the activity post, and the hand-back of a run it launched that reports to nobody are out" "$( LC_ALL=C grep -c -e 'nobody for' -e RIG-START -e RIG-ACTIVITY -e RIG-HAND-AWAY "$rigScn/for.addr" )" "0"
rigAssert "a person's message and a member's own send stay, and so does the hand-back of a run that reports to it" "$( LC_ALL=C grep -c -e RIG-PERSON -e 'a member speaks' -e RIG-HAND-HOME "$rigScn/for.addr" )" "3"
rigDrop keeper-other "$rigScn/rendered" > "$rigScn/for.other"
rigAssert "for keeper-other the DISMISSED, not addressed to it, is out too" "$( LC_ALL=C grep -c 'DISMISSED' "$rigScn/for.other" )" "0"
rigAssert "...and the hand-back of a run keeper-addr launched is news to nobody else's duty but the one it reports to: it stays for keeper-other (it launched nothing)" "$( LC_ALL=C grep -c -e RIG-HAND-AWAY -e RIG-HAND-HOME "$rigScn/for.other" )" "2"

echo "-- 3. the chat file: what is addressed to a run is news, the rest of the tooling's is history --"
: > "$rigScn/index.empty" ; : > "$rigScn/names.empty"
LC_ALL=C awk -v channel=CRIG00001 -v where=CRIG00001:1792422000.000001 -v origin=slack -v seen=- -v historyBefore=0 -v startLine=1 -v startNo=1 -v chatOut="$rigScn/chat.out" -v indexOut="$rigScn/chat.index" \
	-f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsSessionChatImport.awk" "$rigScn/index.empty" "$rigScn/names.empty" "$rigScn/rendered" > /dev/null
rigOrigin(){ ## ts -- the origin the index keeps for the message
	LC_ALL=C awk -F '\t' -v want="$1" '$2 == want { print $4 ; exit }' "$rigScn/chat.index"
}
rigAssert "the DISMISSED addressed to a run is news to its floor (origin slack)" "$( rigOrigin 1792422595.000100 )" "slack"
rigAssert "the note of the tooling addressed to nobody is history" "$( rigOrigin 1792422595.000200 )" "history"
rigAssert "a member's own send and a person's message are news" "$( rigOrigin 1792422595.000300 ):$( rigOrigin 1792422595.000400 )" "slack:slack"
rigAssert "the start post and the activity post of event-track are history" "$( rigOrigin 1792422595.000500 ):$( rigOrigin 1792422595.000800 )" "history:history"
rigAssert "a hand-back is news" "$( rigOrigin 1792422595.000600 ):$( rigOrigin 1792422595.000700 )" "slack:slack"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TRACKING DROP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TRACKING_DROP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
