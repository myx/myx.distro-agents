#!/usr/bin/env bash
## Behavioural check on `AgentsToolsCommsActivityPass` (AgentsTools.SessionComms.include), run rather than read, in a workspace built here: the comms service
## thread posts the activity of the live runs from their logs, and the spawner only adds to the log. Held: a run's tool lines are posted as ONE post in the
## outbox of its thread, at first sight; a pass inside the run's 60 s window posts nothing; a later pass posts only what is after the pointer, and the pointer
## moves forward; a pass with nothing new posts nothing; a run with no thread of its own is not tracked; a run that is not live is not read; a pass looks at
## the runs at most every 20 s and renders at most 8 of them; at most 100 lines go in a post; and the spawner's own poller returns at once unless it is asked
## for. Offline: nothing is posted to any service.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHere/session/AgentsTools.SessionComms.include" ] || rigRefuse "the thread's functions are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsActivityPassCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## A workspace of its own: the real one is never touched. MMDAPP moves to it for the length of the check, and the template, the roster and the thread's
## functions are the real ones.
rigReal="$MMDAPP"
rigWs="$rigTmp/ws"
export MMDAPP="$rigWs"
unset MDAT_SKILLSET_ROOT
mkdir -p "$rigWs/.local/temp"
rigRun(){ ## spawn id, status, owner, thread, log lines... -- one record and its log
	local runId="$1" runStatus="$2" runOwner="$3" runThread="$4" runLog="$rigWs/.local/agents/sessions/$1/session.log"
	shift 4
	mkdir -p "$rigWs/.local/agents/spawned/$runId" "$rigWs/.local/agents/sessions/$runId"
	printf '%s\n' '---' "spawn-id: $runId" "status: $runStatus" "owner: $runOwner" ${runThread:+"agent-log-thread: $runThread"} "output-file: $runLog" '---' > "$rigWs/.local/agents/spawned/$runId/$runId.spawn.md"
	printf '%s\n' "$@" > "$runLog"
}
rigOutbox(){ ## channel-thread dir name -- how many posts wait in it
	local boxFile="$rigWs/.local/cache/comms/slack/slack-$1/outbox.messages.txt"
	[ -f "$boxFile" ] && wc -l < "$boxFile" | tr -d ' ' || printf '0'
}
rigPointer(){ ## spawn id -- the lines read, from its pointer
	local pointerFile="$rigWs/.local/agents/comms/activity/$1"
	[ -f "$pointerFile" ] && cut -d' ' -f2 "$pointerFile" || printf 'none'
}
MDSC_CMD=check . "$rigHere/session/AgentsTools.SessionComms.include" > /dev/null 2>&1
type AgentsToolsCommsActivityPass > /dev/null 2>&1 || rigRefuse "AgentsToolsCommsActivityPass is not defined by sourcing the thread's functions"
## The list of started records is kept for MDAT_STARTED_RECORDS_SECONDS in the product, and the rows below add runs between passes, so they read it fresh; the kept list has its own rows at the end.
export MDAT_STARTED_RECORDS_SECONDS=0
rigLive=yes
AgentsToolsSessionRecordLive(){ [ "$rigLive" = yes ] ; }
rigAt=1800000000
rigA=aaaa1111-0000-0000-0000-000000000001
rigRun "$rigA" spawn-started magic-tester CRIGCHAN:1793000000.000100 'noise' '  -> tool: Read' '  <- tool result' '   💻 Bash x' '   🧠 thinking' 'plain'

AgentsToolsCommsActivityPass "$rigAt"
rigAssert "first sight: the tool lines of the log are one post in its thread's outbox, and the pointer is the lines read" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN-1793000000.000100 ):$( rigPointer "$rigA" )" "yes:1:6"
rigAssert "the record names the member, the bot and the post method" "$( cut -f3,4,5 "$rigWs/.local/cache/comms/slack/slack-CRIGCHAN-1793000000.000100/outbox.messages.txt" | head -1 | tr '\t' ' ' )" "magic-tester bot chat.postMessage"

printf '%s\n' '  -> tool: Grep' 'noise2' >> "$rigWs/.local/agents/sessions/$rigA/session.log"
AgentsToolsCommsActivityPass $(( rigAt + 10 ))
rigAssert "a pass within 20 s of the last looks at nothing" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN-1793000000.000100 )" "no:1"
AgentsToolsCommsActivityPass $(( rigAt + 30 ))
rigAssert "a pass inside the run's 60 s window posts nothing" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN-1793000000.000100 ):$( rigPointer "$rigA" )" "no:1:6"
AgentsToolsCommsActivityPass $(( rigAt + 80 ))
rigAssert "a later pass posts only what is after the pointer, and the pointer moves forward" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN-1793000000.000100 ):$( rigPointer "$rigA" )" "yes:2:8"
rigAssert "the second post holds the new tool line and not the first window's" "$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGCHAN-1793000000.000100/outbox.messages.txt" | cut -f6 | grep -c 'Grep' ):$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGCHAN-1793000000.000100/outbox.messages.txt" | cut -f6 | grep -c 'Bash' )" "1:0"
AgentsToolsCommsActivityPass $(( rigAt + 160 ))
rigAssert "a pass with nothing new posts nothing, and the pointer stands" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN-1793000000.000100 ):$( rigPointer "$rigA" )" "no:2:8"

rigB=bbbb2222-0000-0000-0000-000000000002
rigC=cccc3333-0000-0000-0000-000000000003
rigRun "$rigB" spawn-started magic-developer "" '  -> tool: Read'
rigRun "$rigC" spawn-started keeper-myx CRIGCHAN2:1793000000.000200 '  -> tool: Read'
rigLive=no
AgentsToolsCommsActivityPass $(( rigAt + 400 ))
rigAssert "a run with no thread is not tracked, and a run that is not live is not read: no post, and the second's pointer was never made" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN2-1793000000.000200 ):$( rigPointer "$rigC" )" "no:0:none"
rigAssert "a run with no thread has its window noted, so it is not looked at again for a minute" "$( rigPointer "$rigB" )" "0"
rigLive=yes
AgentsToolsCommsActivityPass $(( rigAt + 430 ))
rigAssert "the run that is live is posted once it is" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGCHAN2-1793000000.000200 )" "yes:1"

## One run with a long log: at most 100 lines go in a post.
rigD=dddd4444-0000-0000-0000-000000000004
rigLines=()
for rigN in $( seq 1 150 ) ; do rigLines+=( "  -> tool: Read file$rigN" ) ; done
rigRun "$rigD" spawn-started magic-librarian CRIGCHAN3:1793000000.000300 "${rigLines[@]}"
AgentsToolsCommsActivityPass $(( rigAt + 600 ))
rigAssert "a log of 150 tool lines posts the last 100 of them, and the pointer is all 150" "$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGCHAN3-1793000000.000300/outbox.messages.txt" | cut -f6 | grep -c 'file150' ):$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGCHAN3-1793000000.000300/outbox.messages.txt" | cut -f6 | grep -c 'file1[^0-9]' ):$( rigPointer "$rigD" )" "1:0:150"

## At most 8 runs a pass.
for rigN in 1 2 3 4 5 6 7 8 9 10 ; do
	rigRun "eeee5555-0000-0000-0000-0000000000$( printf '%02d' "$rigN" )" spawn-started magic-tester "CRIGMANY:17930000$rigN.000000" '  -> tool: Read'
done
AgentsToolsCommsActivityPass $(( rigAt + 1000 ))
rigAssert "ten due runs: a pass renders at most 8 of them" "$( ls "$rigWs/.local/cache/comms/slack" | grep -c '^slack-CRIGMANY-' )" "8"
AgentsToolsCommsActivityPass $(( rigAt + 1030 ))
rigAssert "the next pass takes the two left" "$( ls "$rigWs/.local/cache/comms/slack" | grep -c '^slack-CRIGMANY-' )" "10"

## A run whose feed is on posts its feed and never its log. The feed is taken whole at one window and posted at the next.
rigF=ffff6666-0000-0000-0000-000000000006
rigRun "$rigF" spawn-started magic-tester CRIGFEED:1793000000.000600 '  -> tool: Read dup'
printf '%s\n' '2026-11-07T10:00:00Z ROUND n=1 in=1 cache-read=0 cache-write=0 out=1' '> feed text' > "$rigWs/.local/agents/sessions/$rigF/feed"
: > "$rigWs/.local/agents/sessions/$rigF/feed.open"
AgentsToolsCommsActivityPass $(( rigAt + 2000 ))
rigAssert "a feed run: first window takes the feed aside and posts nothing, not even its log" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGFEED-1793000000.000600 ):$( [ -s "$rigWs/.local/agents/sessions/$rigF/feed.posting" ] && echo taken || echo not ):$( [ -e "$rigWs/.local/agents/sessions/$rigF/feed" ] && echo left || echo gone )" "no:0:taken:gone"
AgentsToolsCommsActivityPass $(( rigAt + 2080 ))
rigAssert "a feed run: the next window posts the taken feed as one post of kind feed, and removes it" "${agentsCommsActivityPosted:-no}:$( rigOutbox CRIGFEED-1793000000.000600 ):$( [ -e "$rigWs/.local/agents/sessions/$rigF/feed.posting" ] && echo left || echo gone ):$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGFEED-1793000000.000600/outbox.messages.txt" | grep -c '"tracking":"feed"' )" "yes:1:gone:1"
rigAssert "a feed run: its log's tool line is not posted a second time" "$( tail -1 "$rigWs/.local/cache/comms/slack/slack-CRIGFEED-1793000000.000600/outbox.messages.txt" | grep -c 'dup' )" "0"
printf '%s\n' '2026-11-07T10:01:00Z ROUND n=2 in=1 cache-read=0 cache-write=0 out=1' > "$rigWs/.local/agents/sessions/$rigF/feed"
printf '%s\n' 'CRIGFEED2:1793000000.000700' > "$rigWs/.local/agents/sessions/$rigF/event-track.thread"
AgentsToolsCommsActivityPass $(( rigAt + 2160 ))
AgentsToolsCommsActivityPass $(( rigAt + 2240 ))
rigAssert "a feed run with an event-track.thread of its own posts there, not in its record's thread" "$( rigOutbox CRIGFEED2-1793000000.000700 ):$( rigOutbox CRIGFEED-1793000000.000600 )" "1:1"

## The started records are read from the tree once in the TTL, and kept.
. "$rigHere/session/AgentsTools.StartedRecords.include" || rigRefuse "the started records' include could not be sourced"
rm -f "$rigWs/.local/agents/schedule/started.records"
rigListA="$( MDAT_STARTED_RECORDS_SECONDS=60 AgentsToolsSpawnedStartedRecords | wc -l | tr -d ' ' )"
rigG=gggg7777-0000-0000-0000-000000000007
rigRun "$rigG" spawn-started magic-tester CRIGKEPT:1793000000.000800 '  -> tool: Read'
rigListB="$( MDAT_STARTED_RECORDS_SECONDS=60 AgentsToolsSpawnedStartedRecords | wc -l | tr -d ' ' )"
rigListC="$( MDAT_STARTED_RECORDS_SECONDS=0 AgentsToolsSpawnedStartedRecords | wc -l | tr -d ' ' )"
rigAssert "the first call reads the tree, a call within the TTL gives the kept list without the run made since, and TTL 0 reads the tree again" "$(( rigListB - rigListA )):$(( rigListC - rigListA ))" "0:1"
rigAssert "the kept list is a file: the epoch on its first line, then a path a line" "$( LC_ALL=C sed -n '1p' "$rigWs/.local/agents/schedule/started.records" | LC_ALL=C grep -c '^[0-9][0-9]*$' ):$( LC_ALL=C sed 1d "$rigWs/.local/agents/schedule/started.records" | LC_ALL=C grep -c 'spawn.md$' )" "1:$rigListB"

## The per-run feed poster returns at once unless it is asked.
eval "$( sed -n '/^AgentsEventTrackFeedRun()/,/^}/p' "$rigHere/session/AgentsTools.EventTrackFeed.include" )"
type AgentsEventTrackFeedRun > /dev/null 2>&1 || rigRefuse "the feed poster is not in the feed include"
rigPollStart="$SECONDS"
rigPollRc=0 ; ( unset MDAT_SPAWN_PROXY_OWN_FEED ; AgentsEventTrackFeedRun "$rigA" magic-tester CRIGCHAN:1 > /dev/null 2>&1 ) || rigPollRc=$?
rigAssert "the feed poster returns at once, rc 0, so no run keeps one" "$rigPollRc:$(( SECONDS - rigPollStart < 5 ? 1 : 0 ))" "0:1"

## The spawner's own poller does nothing unless it is asked.
## The function alone is taken out of the include: the include is a whole arm of the tool and ends a shell that sources it with no operation.
eval "$( sed -n '/^AgentsToolsSpawnProxyEventTrackBatch()/,/^}/p' "$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include" )"
type AgentsToolsSpawnProxyEventTrackBatch > /dev/null 2>&1 || rigRefuse "the spawner's poller is not in the proxy include"
rigPollStart="$SECONDS"
rigPollRc=0 ; ( unset MDAT_SPAWN_PROXY_OWN_ACTIVITY ; AgentsToolsSpawnProxyEventTrackBatch CRIGCHAN:1 magic-tester "$rigWs/.local/agents/sessions/$rigA/session.log" > /dev/null 2>&1 ) || rigPollRc=$?
rigAssert "the spawner's poller returns at once, rc 0, so no run keeps a poller of its own" "$rigPollRc:$(( SECONDS - rigPollStart < 5 ? 1 : 0 ))" "0:1"
export MMDAPP="$rigReal"
if [ "$rigFails" -ne 0 ] ; then echo "⛔ COMMS ACTIVITY PASS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1 ; fi
echo "COMMS_ACTIVITY_PASS: OK ($rigPasses assertions, offline)"
