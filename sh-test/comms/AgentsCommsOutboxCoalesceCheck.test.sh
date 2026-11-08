#!/usr/bin/env bash
## Behavioural check on the joining of tracking posts in a comms outbox (AgentsCommsOutboxCoalesce.awk and the pusher AgentsToolsCommsCachePush), run rather than
## read, in a workspace built here, with the one post to Slack a stub. Held: tracking posts of one member and one session are one message up to 50
## blocks, a box's children counted, and the joined payload is valid JSON with the first post's text and metadata; a message of a member, a notice, another
## member's post and a post of another method are written as they came and break the run, first, ahead of the tracking posts, which a channel takes one message a second; the posts already sent are written
## as they were, so the position the pusher keeps points at the same record; a reason a post kept stays on the joined one; a line of the wrong shape passes
## through; the pusher joins a file once, posts every box of it exactly once, and cleans its files; a post that fails in the middle of a joined file is tried again,
## and the rest goes after it, with no box posted twice and none lost. Offline: nothing is posted to any service.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/comms/AgentsCommsOutboxCoalesce.awk" ] || rigRefuse "the joining awk is not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsOutboxCoalesceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigAwk="$rigHere/comms/AgentsCommsOutboxCoalesce.awk"
rigTab=$'\t' rigSep=$'\037'

## A record as the outbox keeps it: session, block, member, identity, method, payload; a tracking post is one box of three blocks (a container and two sections).
rigBox='{"type":"container","width":"full","children":[{"type":"section","text":"a"},{"type":"context","text":"b"}]}'
rigPost(){ ## session, block, member, kind (activity|notice), box number, [method] [why]
	local postKind="$4" postMethod="${6:-chat.postMessage}" postWhy="${7:-}" postBody
	postBody="{\"channel\":\"CRIG\",\"text\":\"$3 · 1 line\",\"blocks\":[${rigBox/\"a\"/\"box$5\"}],\"thread_ts\":\"1793000000.000100\",\"metadata\":{\"event_type\":\"magic_sender\",\"event_payload\":{\"sender\":\"$3\",\"tracking\":\"$postKind\",\"session\":\"$1\"}}}"
	[ -z "$postWhy" ] || postBody="why=$postWhy${rigSep}$postBody"
	printf '%s\t%s\t%s\tbot\t%s\t%s\n' "$1" "$2" "$3" "$postMethod" "$postBody"
}
rigBoxes(){ ## a payload -- how many boxes it holds
	printf '%s\n' "$1" | grep -o '"type":"container"' | wc -l | tr -d ' '
}
rigField6(){ ## file, line -- the payload
	sed -n "${2}p" "$1" | cut -f6
}

echo "-- the awk --"
rigIn="$rigTmp/in.txt"
{
	for n in $( seq 1 20 ) ; do rigPost sA "17900000$n" magic-tester activity "$n" ; done
	rigPost sA 1790000021 magic-tester notice 21
	rigPost sA 1790000022 magic-developer activity 22
	rigPost sA 1790000023 magic-developer activity 23
	rigPost sB 1790000024 magic-developer activity 24
	rigPost sB 1790000025 magic-developer activity 25 chat.update
	printf 'not six columns\n'
} > "$rigIn"
LC_ALL=C awk -v sent=0 -f "$rigAwk" "$rigIn" > "$rigTmp/out0.txt"
rigAssert "26 records become 7: the notice, the other method's one and the stray line first, as they came, then the first 16 boxes of a tester, its next 4, the developer's two, the other session's one" \
	"$( wc -l < "$rigTmp/out0.txt" | tr -d ' ' )" "7"
rigAssert "a notice, a post of another method and a line of the wrong shape are written first, in the order they came" "$( sed -n 1p "$rigTmp/out0.txt" | cut -f6 | grep -c '"tracking":"notice"' ):$( sed -n 2p "$rigTmp/out0.txt" | cut -f5 ):$( sed -n 3p "$rigTmp/out0.txt" )" "1:chat.update:not six columns"
rigAssert "the first tracking message holds 16 boxes (16 of weight 3 is 48, the 17th would pass 50), and the second the other 4" "$( rigBoxes "$( rigField6 "$rigTmp/out0.txt" 4 )" ):$( rigBoxes "$( rigField6 "$rigTmp/out0.txt" 5 )" )" "16:4"
rigAssert "a joined payload is valid JSON, with the thread, and the first post's text kept" \
	"$( rigField6 "$rigTmp/out0.txt" 4 | python3 -I -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d["thread_ts"], d["text"], len(d["blocks"]), d["metadata"]["event_payload"]["tracking"])' )" "1793000000.000100 magic-tester · 1 line 16 activity"
rigAssert "the boxes are in the order they came, the first and the last of the 16" "$( rigField6 "$rigTmp/out0.txt" 4 | grep -o 'box[0-9]*' | sed -n '1p;16p' | tr '\n' ' ' )" "box1 box16 "
rigAssert "another member's posts do not join the tester's, and join each other: two boxes" "$( rigBoxes "$( rigField6 "$rigTmp/out0.txt" 6 )" )" "2"
rigAssert "another session's post is not joined to the developer's of the first: one box" "$( rigBoxes "$( rigField6 "$rigTmp/out0.txt" 7 )" )" "1"

{
	for n in 1 2 3 ; do rigPost sF "17910000$n" magic-librarian feed "$n" ; done
	rigPost sF 1791000004 magic-librarian activity 4
	for n in 5 6 ; do rigPost sF "17910000$n" magic-librarian feed "$n" ; done
	rigPost sF 1791000007 magic-librarian refusal 7
} > "$rigTmp/feed.txt"
LC_ALL=C awk -v sent=0 -f "$rigAwk" "$rigTmp/feed.txt" > "$rigTmp/feed.out"
rigAssert "feed posts join as activity posts do, and the two kinds never share a message, nor a refusal one: 3 feed, 1 activity, 2 feed, 1 refusal" \
	"$( wc -l < "$rigTmp/feed.out" | tr -d ' ' ):$( for n in 1 2 3 4 ; do rigBoxes "$( rigField6 "$rigTmp/feed.out" "$n" )" ; done | tr '\n' ' ' )" "4:1 3 1 2 "

LC_ALL=C awk -v sent=5 -f "$rigAwk" "$rigIn" > "$rigTmp/out5.txt"
rigAssert "the first 5 records, already sent, are written as they were" "$( head -5 "$rigTmp/out5.txt" | cksum ):$( head -5 "$rigIn" | cksum )" "$( head -5 "$rigIn" | cksum ):$( head -5 "$rigIn" | cksum )"
rigAssert "the rest is joined: 15 boxes of the tester in one message after them" "$( rigBoxes "$( rigField6 "$rigTmp/out5.txt" 9 )" )" "15"
{ rigPost sA 1 magic-tester activity 1 chat.postMessage "queued for the comms reader" ; rigPost sA 2 magic-tester activity 2 chat.postMessage "queued for the comms reader" ; } > "$rigTmp/why.txt"
LC_ALL=C awk -v sent=0 -f "$rigAwk" "$rigTmp/why.txt" > "$rigTmp/why.out"
rigAssert "a reason a post kept stays on the joined one, once, with both boxes after it" "$( wc -l < "$rigTmp/why.out" | tr -d ' ' ):$( rigField6 "$rigTmp/why.out" 1 | head -c 31 ):$( rigField6 "$rigTmp/why.out" 1 | tr "$rigSep" '\n' | tail -1 | grep -o '"type":"container"' | wc -l | tr -d ' ' )" "1:why=queued for the comms reader:2"

echo "-- the pusher --"
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local" "$rigWs/cache"
export MMDAPP="$rigWs" MDSC_CMD=check
set +u
. "$rigHere/comms/AgentsTools.CommsCache.include" > /dev/null 2>&1
set -u
type AgentsToolsCommsCachePush > /dev/null 2>&1 || rigRefuse "the pusher is not defined by sourcing the comms cache"
rigPostLog="$rigTmp/posts.log" rigFailAt=0 rigCalls=0
AgentsToolsSessionCommsDir(){ printf '%s\n' "$rigTmp/commsdir" ; }
AgentsToolsSessionCommsPost(){ ## session, the retry file -- the stub post: counts the boxes it was given
	rigCalls=$(( rigCalls + 1 ))
	if [ "$rigFailAt" -gt 0 ] && [ "$rigCalls" -eq "$rigFailAt" ] ; then return 1 ; fi
	printf '%s\n' "$( sed -n 3p "$2" | grep -o '"type":"container"' | wc -l | tr -d ' ' )" >> "$rigPostLog"
	return 0
}
rigBoxDir="$rigTmp/box"
rigReset(){ rm -rf "$rigBoxDir" "$rigPostLog" ; mkdir -p "$rigBoxDir" ; rigCalls=0 rigFailAt=0 ; }
rigBoxesPosted(){ [ -f "$rigPostLog" ] && awk '{ n += $1 } END { print n + 0 }' "$rigPostLog" || printf '0' ; }
rigMessages(){ [ -f "$rigPostLog" ] && wc -l < "$rigPostLog" | tr -d ' ' || printf '0' ; }

rigReset
for n in $( seq 1 40 ) ; do rigPost sA "$n" magic-tester activity "$n" ; done > "$rigBoxDir/outbox.messages.txt"
AgentsToolsCommsCachePush "$rigBoxDir" 1000 0
rigAssert "40 one-box posts go as 3 messages (16, 16, 8) and every box is posted once" "$( rigMessages ):$( rigBoxesPosted )" "3:40"
rigAssert "the pusher cleans its files when all is sent" "$( ls -A "$rigBoxDir" | tr '\n' ' ' | sed 's/ $//' )" ""

rigReset
for n in $( seq 1 40 ) ; do rigPost sA "$n" magic-tester activity "$n" ; done > "$rigBoxDir/outbox.messages.txt"
rigFailAt=2
AgentsToolsCommsCachePush "$rigBoxDir" 1000 0
rigAssert "the second message fails: the first (16 boxes) went, and the file waits, joined once, with its retry time set" "$( rigMessages ):$( rigBoxesPosted ):$( [ -f "$rigBoxDir/.merged.txt" ] && echo merged ):$( [ -f "$rigBoxDir/outbox.pushing.txt" ] && echo waits )" "1:16:merged:waits"
rigFailAt=0
AgentsToolsCommsCachePush "$rigBoxDir" 1000 0
rigAssert "before its retry time nothing is posted" "$( rigBoxesPosted )" "16"
AgentsToolsCommsCachePush "$rigBoxDir" 9999999999 0
rigAssert "after it the rest goes, with no box twice and none lost: 40 in all, and the files are gone" "$( rigBoxesPosted ):$( ls -A "$rigBoxDir" | tr '\n' ' ' | sed 's/ $//' )" "40:"

export MMDAPP="$MMDAPP"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ COMMS OUTBOX COALESCE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "COMMS_OUTBOX_COALESCE: OK ($rigPasses assertions, offline)"
