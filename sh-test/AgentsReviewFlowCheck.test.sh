#!/usr/bin/env bash
## Behavioural check on the review flow (AgentsTools.ReviewFlow.include) and the endings the
## tooling orders. Into review, five ways: a served SubagentHandback, a child that ended with
## no handback, a --wait pass that ended, a review request, and the close fix (a close never
## moves an item out of review, processed or pending). The review limit: a served Wait at
## REVIEW_WAIT_LIMIT ends the session, recorded once, the item staying in review. The
## verdicts: accept, return (delivered to a live child; restarting an ended session), reject,
## follow-up, each with its board move, its send, its Decisions line and its transcript line.
## A routine as review-by, listed by its own input scan and left alone by advance
## housekeeping. The endings: archive, trash, shutdown, TaskStop. The coordinator-thread
## fallback for a spawn whose parent has no thread.
## Offline: a fake `curl` first on PATH logs each Slack call and opens no socket; a fake
## DistroAgentsConsole.sh stands in for the CLI; the board, sandboxes and workspace are this
## rig's own temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
rigTmp="$( mktemp -d -t AgentsReviewFlowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'for rigPid in $rigLivePids ; do pkill -P "$rigPid" 2> /dev/null ; kill "$rigPid" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/board/pending" \
	"$rigWs/.local/.agents" "$rigSpawned" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-coordinator keeper-myx magic-tester ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
## The fake console: the vintage strings the proxy greps for; its stdin kept per spawn.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat >> "$RIG_TMP/console-in.$MDAT_SPAWN_SESSION_ID"\necho rig-child-output\nexit 0\n' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One command in the rig, guarded to its own trees, the fake curl first on PATH. Extra
## environment as NAME=value words in rigEnv. Output into <result>, rc into <result>.rc.
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	: > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	env -i HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigOp(){ ## result file, DistroAgentsTools.fn.sh args...
	local opOut="$1" ; shift
	rigRun "$opOut" bash "$rigFn" "$@"
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call
	printf '%s\n' "$3" > "$rigTmp/tool.args"
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigTmp/tool.args"
}
rigItem(){ ## state, item stem, spawn-id or empty, extra frontmatter lines (may be empty)
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\n%s%s---\n\n# rig dispatch\n' "${3:+spawn-id: $3
}" "${4:-}" > "$rigData/board/$1/$2.md"
}
rigRecord(){ ## spawn-id, status, session-thread or empty, item stem or empty, folder (default: spawn-id), extra lines
	local recFolder="${5:-$1}"
	mkdir -p "$rigSpawned/$recFolder"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-session-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n%s%s%s---\n' \
		"$1" "$1" "$recFolder" "$rigHost" "$2" "${3:+session-thread: $3
}" "${4:+spawns: $4
}" "${6:-}" > "$rigSpawned/$recFolder/$1.md"
}
rigLive(){ ## spawn-id -- a stand-in process carrying the spawn id in its argv
	bash -c 'sleep 300 ; :' "$1" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!"
	disown "$!" 2> /dev/null || :
}
rigTranscript(){ ## spawn-id -- the transcript pointer every writer resolves
	mkdir -p "$rigWs/.local/agents/sessions/$1"
	: > "$rigTmp/tr-$1.log"
	printf '%s\n' "$rigTmp/tr-$1.log" > "$rigWs/.local/agents/sessions/$1/transcript"
}
rigLoc(){ ## item stem -- the board state holding it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigDecisions(){ ## item path, pattern -- matching Decisions lines
	LC_ALL=C grep -c -E "^- [0-9TZ:-]+ [a-z-]+ $2" "$1" 2> /dev/null || :
}
rigPosts(){ LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" 2> /dev/null || : ; }
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}

## ---------------------------------------------------------------- into review
echo "-- 1. a served SubagentHandback: running -> review, Decisions handback, transcript REVIEW --"
rigRecord rig-par-1 spawn-started CPAR00001:1700000000.000100 "" rig-par-1
rigRecord rig-child-1 spawn-started "" dispatch-20261008T1200Z-hb rig-child-1 'parent-session-id: rig-par-1
'
## parent-session-id is set twice above; the first one wins for every reader, so rewrite it.
LC_ALL=C sed -i.bak 's/^parent-session-id: none$/parent-session-id: rig-par-1/' "$rigSpawned/rig-child-1/rig-child-1.md" && rm -f "$rigSpawned/rig-child-1/rig-child-1.md.bak"
rigItem running dispatch-20261008T1200Z-hb rig-child-1
rigTranscript rig-child-1
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-1 )
rigTool "$rigTmp/h1" SubagentHandback '{"outcome":"rig work done","task":"rig"}'
rigEnv=()
rigAssert "the handback is posted"                         "$( LC_ALL=C grep -c '^SENT_MESSAGE_TS=' "$rigTmp/h1" )" 1
rigAssert "into the parent session thread"                 "$( LC_ALL=C grep -c '"channel": *"CPAR00001"' "$rigTmp/bodies" )" 1
rigAssert "the item moved running -> review"               "$( rigLoc dispatch-20261008T1200Z-hb )" review
rigAssert "its review-reason is handback"                  "$( LC_ALL=C grep -c -x 'review-reason: handback' "$rigData/board/review/dispatch-20261008T1200Z-hb.md" )" 1
rigAssert "one Decisions handback line"                    "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-hb.md" 'handback: handback: rig work done' )" 1
rigAssert "one transcript REVIEW line"                     "$( LC_ALL=C grep -c ' REVIEW item=dispatch-20261008T1200Z-hb kind=handback ' "$rigTmp/tr-rig-child-1.log" )" 1

echo "-- 1b. a handback delivered to an inbox (no Slack DM) moves the item too; a failed delivery moves nothing --"
rigRecord rig-child-ib spawn-started "" dispatch-20261008T1200Z-ib rig-child-ib
rigItem running dispatch-20261008T1200Z-ib rig-child-ib
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-ib )
rigTool "$rigTmp/h1b" SubagentHandback '{"outcome":"inbox work done","to":"magic-tester"}'
rigEnv=()
rigAssert "the handback goes to the inbox"                 "$( LC_ALL=C grep -c '^Sent to the inbox of magic-tester as inquiry-' "$rigTmp/h1b" ):$( ls "$rigData/inboxes/magic-tester"/inquiry-*.md 2> /dev/null | wc -l | tr -d ' ' )" 1:1
rigAssert "the item moved running -> review"               "$( rigLoc dispatch-20261008T1200Z-ib )" review
rigAssert "one Decisions handback line"                    "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-ib.md" 'handback: handback: inbox work done' )" 1
rigRecord rig-child-nf spawn-started "" dispatch-20261008T1200Z-nf rig-child-nf
rigItem running dispatch-20261008T1200Z-nf rig-child-nf
mkdir -p "$rigData/inboxes" && : > "$rigData/inboxes/magic-coordinator"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-nf )
rigTool "$rigTmp/h1c" SubagentHandback '{"outcome":"never delivered","to":"magic-coordinator"}'
rigEnv=()
rm -f "$rigData/inboxes/magic-coordinator"
rigAssert "a refused inbox delivers nothing"               "$( LC_ALL=C grep -c '^ERROR: magic-coordinator has no Slack DM channel, and its inbox refused the hand-off' "$rigTmp/h1c" )" 1
rigAssert "and moves nothing"                              "$( rigLoc dispatch-20261008T1200Z-nf ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-nf.md" 'handback:' )" running:0
printf '7\n7\n7\n7\n7\n7\n' > "$rigTmp/post-exits"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-nf )
rigTool "$rigTmp/h1d" SubagentHandback '{"outcome":"never posted","to":"CNF000001:1700000000.000150"}'
rigEnv=()
rm -f "$rigTmp/post-exits"
rigAssert "a failed Slack send moves nothing"              "$( LC_ALL=C grep -c '^ERROR: the send failed' "$rigTmp/h1d" ):$( rigLoc dispatch-20261008T1200Z-nf ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-nf.md" 'handback:' )" 1:running:0

echo "-- 2. a review request (a member or the human): running -> review with its reason --"
rigItem running dispatch-20261008T1200Z-rq ""
rigOp "$rigTmp/q0" --member-review-request magic-tester dispatch-20261008T1200Z-rq --reason "not mine"
rigAssert "a member that is neither owner nor spawner is refused" "$( cat "$rigTmp/q0.rc" ):$( rigLoc dispatch-20261008T1200Z-rq ):$( LC_ALL=C grep -c 'neither the owner of' "$rigTmp/q0" )" 1:running:1
rigEnv=( MDAT_SPAWN_AGENT=magic-tester )
rigOp "$rigTmp/q0s" --member-review-request keeper-myx dispatch-20261008T1200Z-rq --reason "as the owner"
rigEnv=()
rigAssert "a session naming the owner is refused"          "$( cat "$rigTmp/q0s.rc" ):$( rigLoc dispatch-20261008T1200Z-rq ):$( LC_ALL=C grep -c 'this session acts as magic-tester' "$rigTmp/q0s" )" 1:running:1
rigOp "$rigTmp/q1" --member-review-request keeper-myx dispatch-20261008T1200Z-rq --reason "looks finished"
rigAssert "the op succeeds"                                "$( cat "$rigTmp/q1.rc" )" 0
rigAssert "the item is in review"                          "$( rigLoc dispatch-20261008T1200Z-rq )" review
rigAssert "the reason is review-requested"                 "$( LC_ALL=C grep -c -x 'review-reason: review-requested' "$rigData/board/review/dispatch-20261008T1200Z-rq.md" )" 1
rigAssert "Decisions names who asked and why"              "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-rq.md" 'review: review-requested: by keeper-myx: looks finished' )" 1
rigItem running dispatch-20261008T1200Z-rqp rig-child-rqp
rigRecord rig-child-rqp spawn-succeeded "" dispatch-20261008T1200Z-rqp
LC_ALL=C sed -i.bak 's/^parent-session-id: none$/parent-session-id: rig-par-rq/' "$rigSpawned/rig-child-rqp/rig-child-rqp.md" && rm -f "$rigSpawned/rig-child-rqp/rig-child-rqp.md.bak"
rigRecord rig-par-rq spawn-succeeded "" ""
LC_ALL=C sed -i.bak 's/^owner: keeper-myx$/owner: magic-tester/' "$rigSpawned/rig-par-rq/rig-par-rq.md" && rm -f "$rigSpawned/rig-par-rq/rig-par-rq.md.bak"
rigEnv=( MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-par-rq )
rigOp "$rigTmp/q1p" --member-review-request magic-tester dispatch-20261008T1200Z-rqp --reason "my child is done"
rigEnv=()
rigAssert "the session that spawned it asks too"           "$( cat "$rigTmp/q1p.rc" ):$( rigLoc dispatch-20261008T1200Z-rqp )" 0:review
rigOp "$rigTmp/q2" --member-review-request keeper-myx dispatch-20261008T1200Z-rq --reason "again"
rigAssert "a second request moves nothing out of review"   "$( LC_ALL=C grep -c 'only a running item enters review' "$rigTmp/q2" ):$( rigLoc dispatch-20261008T1200Z-rq )" 1:review

echo "-- 3. the close fix: only a running item moves; review, processed and pending stay --"
for rigState in review processed pending ; do
	rigItem "$rigState" "dispatch-20261008T1200Z-close-$rigState" ""
	rigRun "$rigTmp/c-$rigState" bash -c '. "$1" ; . "$2" ; AgentsToolsSpawnProxyCloseDispatch "$3" "" 0 rig.log succeeded running review' \
		rig "$rigFn" "$rigLib/AgentsTools.SpawnSandbox.include" "dispatch-20261008T1200Z-close-$rigState.md"
	rigAssert "an item in $rigState stays in $rigState"    "$( rigLoc "dispatch-20261008T1200Z-close-$rigState" )" "$rigState"
done
rigAssert "the review item gets its Result in place"       "$( LC_ALL=C grep -c '^## Result' "$rigData/board/review/dispatch-20261008T1200Z-close-review.md" )" 1
rigAssert "the processed item is left untouched"           "$( LC_ALL=C grep -c '^## Result' "$rigData/board/processed/dispatch-20261008T1200Z-close-processed.md" )" 0
rigItem running dispatch-20261008T1200Z-close-running ""
rigRun "$rigTmp/c-running" bash -c '. "$1" ; . "$2" ; AgentsToolsSpawnProxyCloseDispatch "$3" "" 0 rig.log succeeded running review' \
	rig "$rigFn" "$rigLib/AgentsTools.SpawnSandbox.include" dispatch-20261008T1200Z-close-running.md
rigAssert "a running one moves to review"                  "$( rigLoc dispatch-20261008T1200Z-close-running )" review
rigAssert "as ended-without-handback, in Decisions"        "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-close-running.md" 'review: ended-without-handback' )" 1

echo "-- 4. a child ended with no handback (async spawn): running -> review, ended-without-handback --"
rigEnv=( MDAT_SPAWN_SESSION_ID=rig-par-1 )
rigRun "$rigTmp/p4" bash -c 'printf "rig brief" | bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:create' "$rigFn"
rigEnv=()
rigItem4="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/p4" | head -1 )" ; rigItem4="${rigItem4%.md}"
rigAssert "the spawn starts"                               "$( LC_ALL=C grep -c '^STATUS=started$' "$rigTmp/p4" )" 1
## What is asserted below, not only the move: its Decisions and transcript lines land after it.
rigSettled4(){
	local settledSpawn
	[ -f "$rigData/board/review/$rigItem4.md" ] || return 1
	[ "$( rigDecisions "$rigData/board/review/$rigItem4.md" 'review: ended-without-handback' )" -ge 1 ] 2> /dev/null || return 1
	settledSpawn="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/review/$rigItem4.md" | head -1 )"
	[ -n "$settledSpawn" ] && LC_ALL=C grep -q " REVIEW item=$rigItem4 kind=review " "$rigData"/audit/*/session-*"${settledSpawn:0:8}"*.log 2> /dev/null
}
rigWaitFor 40 rigSettled4
rigAssert "its item lands in review once the child ends"   "$( rigLoc "$rigItem4" )" review
rigAssert "review-reason ended-without-handback"           "$( LC_ALL=C grep -c -x 'review-reason: ended-without-handback' "$rigData/board/review/$rigItem4.md" )" 1
rigAssert "Decisions records it"                           "$( rigDecisions "$rigData/board/review/$rigItem4.md" 'review: ended-without-handback' )" 1
rigSpawn4="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/review/$rigItem4.md" | head -1 )"
rigAssert "and its transcript does"                        "$( LC_ALL=C grep -h -c " REVIEW item=$rigItem4 kind=review " "$rigData"/audit/*/session-*"${rigSpawn4:0:8}"*.log 2> /dev/null | head -1 )" 1
rigAssert "its record names the parent's own thread"       "$( LC_ALL=C grep -h -c -x 'parent-thread: CPAR00001:1700000000.000100' "$rigSpawned"/*/"$rigSpawn4.md" )" 1

echo "-- 5. a --wait pass ended, its parent with no thread: review as wait-pass-ended, coordinator thread fallback --"
rigRecord rig-par-nothread spawn-started "" "" rig-par-nothread
rigRecord rig-coord-1 spawn-started CCOORD001:1700000000.000200 "" rig-coord-1
LC_ALL=C sed -i.bak 's/^owner: keeper-myx$/owner: magic-coordinator/' "$rigSpawned/rig-coord-1/rig-coord-1.md" && rm -f "$rigSpawned/rig-coord-1/rig-coord-1.md.bak"
rigEnv=( MDAT_SPAWN_SESSION_ID=rig-par-nothread )
rigRun "$rigTmp/p5" bash -c 'printf "rig brief" | bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:create --wait' "$rigFn"
rigEnv=()
rigItem5="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/p5" | head -1 )" ; rigItem5="${rigItem5%.md}"
rigAssert "the item is in review"                          "$( rigLoc "$rigItem5" )" review
rigAssert "review-reason wait-pass-ended"                  "$( LC_ALL=C grep -c -x 'review-reason: wait-pass-ended' "$rigData/board/review/$rigItem5.md" )" 1
rigSpawn5="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/review/$rigItem5.md" | head -1 )"
rigAssert "the child's parent-thread is magic-coordinator's" "$( LC_ALL=C grep -h -c -x 'parent-thread: CCOORD001:1700000000.000200' "$rigSpawned"/*/"$rigSpawn5.md" )" 1
## The child's handback to session-parent now has somewhere to go.
rigItem running dispatch-20261008T1200Z-fb rig-child-fb
rigRecord rig-child-fb spawn-started "" dispatch-20261008T1200Z-fb rig-child-fb 'parent-thread: CCOORD001:1700000000.000200
'
LC_ALL=C sed -i.bak 's/^parent-session-id: none$/parent-session-id: rig-par-nothread/' "$rigSpawned/rig-child-fb/rig-child-fb.md" && rm -f "$rigSpawned/rig-child-fb/rig-child-fb.md.bak"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-fb )
rigTool "$rigTmp/h5" SubagentHandback '{"outcome":"fallback done"}'
rigEnv=()
rigAssert "the handback posts, no thread error"            "$( LC_ALL=C grep -c 'has no recorded thread' "$rigTmp/h5" ):$( LC_ALL=C grep -c '"channel": *"CCOORD001"' "$rigTmp/bodies" )" 0:1
rigAssert "and its item enters review"                     "$( rigLoc dispatch-20261008T1200Z-fb )" review

## ---------------------------------------------------------------- the review limit
echo "-- 6. review-limit expiry: a served Wait at REVIEW_WAIT_LIMIT ends the session, recorded once --"
printf 'REVIEW_WAIT_LIMIT=1\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
LC_ALL=C sed -i.bak 's/^review-since-epoch: .*/review-since-epoch: 1000/' "$rigData/board/review/dispatch-20261008T1200Z-hb.md" && rm -f "$rigData/board/review/dispatch-20261008T1200Z-hb.md.bak"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-1 )
rigTool "$rigTmp/w1" Wait '{}'
rigTool "$rigTmp/w2" Wait '{}'
rigEnv=()
rigAssert "the Wait returns DISMISSED"                     "$( LC_ALL=C grep -c -x 'WAIT-RESULT: DISMISSED' "$rigTmp/w1" )" 1
rigAssert "naming review-wait-expired"                     "$( LC_ALL=C grep -c 'WAIT-DISMISSED-BY: tooling (review-wait-expired' "$rigTmp/w1" )" 1
rigAssert "no Slack call was made"                         "$( rigPosts )" 0
rigAssert "the item stays in review"                       "$( rigLoc dispatch-20261008T1200Z-hb )" review
rigAssert "one Decisions line, for two Waits"              "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-hb.md" 'dismissed: review-wait-expired' )" 1
rigAssert "a transcript ENDING line"                       "$( LC_ALL=C grep -c ' ENDING item=dispatch-20261008T1200Z-hb kind=dismissed ' "$rigTmp/tr-rig-child-1.log" )" 1
LC_ALL=C sed -i.bak '/^REVIEW_WAIT_LIMIT=/d' "$rigWs/.local/.agents/magic-team.agent.env" && rm -f "$rigWs/.local/.agents/magic-team.agent.env.bak"
rigRun "$rigTmp/w3" bash -c '. "$1" ; . "$2" ; AgentsReviewWaitLeft rig-child-fb' rig "$rigFn" "$rigLib/AgentsTools.ReviewFlow.include"
rigAssert "under the default 3600s limit, time is left"    "$( LC_ALL=C grep -c -E '^3[56][0-9]{2}$' "$rigTmp/w3" )" 1

## ---------------------------------------------------------------- verdicts
echo "-- 7. accept: -> processed, DISMISSED to the live child, Decisions and transcript --"
rigLive rig-live-acc-$$
rigRecord rig-live-acc-$$ spawn-started CACC00001:1700000000.000300 dispatch-20261008T1200Z-acc
rigItem review dispatch-20261008T1200Z-acc rig-live-acc-$$
rigTranscript rig-live-acc-$$
sleep 1
rigOp "$rigTmp/v1" --member-review-accept magic-coordinator dispatch-20261008T1200Z-acc --summary "good work"
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v1.rc" )" 0
rigAssert "the item is processed"                          "$( rigLoc dispatch-20261008T1200Z-acc )" processed
rigAssert "DISMISSED went to the child's thread"           "$( rigPosts ):$( LC_ALL=C grep -c '"channel": *"CACC00001"' "$rigTmp/bodies" )" 1:1
rigAssert "Decisions: verdict accepted"                    "$( rigDecisions "$rigData/board/processed/dispatch-20261008T1200Z-acc.md" 'verdict: accepted: good work' )" 1
rigAssert "transcript: VERDICT"                            "$( LC_ALL=C grep -c " VERDICT item=dispatch-20261008T1200Z-acc kind=verdict " "$rigTmp/tr-rig-live-acc-$$.log" )" 1

echo "-- 8. return to a live child: -> running, the corrections delivered in its thread --"
rigLive rig-live-ret-$$
rigRecord rig-live-ret-$$ spawn-started CRET00001:1700000000.000400 dispatch-20261008T1200Z-ret
rigItem review dispatch-20261008T1200Z-ret rig-live-ret-$$ 'review-since-epoch: 1000
'
rigTranscript rig-live-ret-$$
sleep 1
rigOp "$rigTmp/v2" --member-review-return magic-coordinator dispatch-20261008T1200Z-ret --message "fix the rig widget"
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v2.rc" )" 0
rigAssert "the item is running again"                      "$( rigLoc dispatch-20261008T1200Z-ret )" running
rigAssert "review-since-epoch is cleared"                  "$( LC_ALL=C grep -c '^review-since-epoch:' "$rigData/board/running/dispatch-20261008T1200Z-ret.md" )" 0
rigAssert "the corrections are in the body"                "$( LC_ALL=C grep -c -x 'fix the rig widget' "$rigData/board/running/dispatch-20261008T1200Z-ret.md" )" 1
rigAssert "delivered in the child's thread, to the child"  "$( LC_ALL=C grep -c 'RETURN: delivered to keeper-myx in CRET00001' "$rigTmp/v2" ):$( LC_ALL=C grep -c 'RETURNED for corrections' "$rigTmp/bodies" )" 1:1
rigAssert "Decisions: verdict returned"                    "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-ret.md" 'verdict: returned: fix the rig widget' )" 1
rigAssert "transcript: VERDICT"                            "$( LC_ALL=C grep -c " VERDICT item=dispatch-20261008T1200Z-ret " "$rigTmp/tr-rig-live-ret-$$.log" )" 1
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-live-ret-$$ )
rigTool "$rigTmp/v2h" SubagentHandback '{"outcome":"fixed","to":"CRET00001:1700000000.000400"}'
rigEnv=()
rigAssert "its next handback goes to review again"         "$( rigLoc dispatch-20261008T1200Z-ret )" review

echo "-- 9. return to an ended session: the same session restarted, with corrections and Decisions --"
rigRecord rig-ended-ret spawn-succeeded CEND00001:1700000000.000500 dispatch-20261008T1200Z-rst trk-rig-rst
rigItem review dispatch-20261008T1200Z-rst rig-ended-ret
rigOp "$rigTmp/v3" --member-review-return magic-coordinator dispatch-20261008T1200Z-rst --message "redo the rig step"
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v3.rc" )" 0
rigAssert "it says it restarted the session"               "$( LC_ALL=C grep -c '^RETURN: restarted keeper-myx on dispatch-20261008T1200Z-rst' "$rigTmp/v3" )" 1
rigNewRecord="$( for rigCandidate in "$rigSpawned/trk-rig-rst"/*.md ; do [ "${rigCandidate##*/}" = rig-ended-ret.md ] || printf '%s\n' "$rigCandidate" ; done | head -1 )"
rigAssert "a new spawn joined the same sandbox"            "$( [ -n "$rigNewRecord" ] && LC_ALL=C grep -c -x 'spawned-by: dispatch-20261008T1200Z-rst' "$rigNewRecord" )" 1
rigNewSpawn="${rigNewRecord##*/}" ; rigNewSpawn="${rigNewSpawn%.md}"
rigWaitFor 20 test -s "$rigTmp/console-in.$rigNewSpawn"
rigAssert "its brief carries the corrections"              "$( LC_ALL=C grep -c -x 'redo the rig step' "$rigTmp/console-in.$rigNewSpawn" )" 1
rigAssert "and the item's Decisions first"                 "$( LC_ALL=C grep -c '^### Decisions (from dispatch-20261008T1200Z-rst)' "$rigTmp/console-in.$rigNewSpawn" )" 1
rigAssert "the item names the new spawn"                   "$( LC_ALL=C grep -h -c -x "spawn-id: $rigNewSpawn" "$rigData"/board/*/dispatch-20261008T1200Z-rst.md )" 1
rigWaitFor 40 test -f "$rigData/board/review/dispatch-20261008T1200Z-rst.md"
rigAssert "it ends with no handback, so back to review"    "$( rigLoc dispatch-20261008T1200Z-rst )" review

echo "-- 10. reject: -> pending, the child dismissed, corrections in Decisions for the fresh spawn --"
rigLive rig-live-rej-$$
rigRecord rig-live-rej-$$ spawn-started CREJ00001:1700000000.000600 dispatch-20261008T1200Z-rej
rigItem review dispatch-20261008T1200Z-rej rig-live-rej-$$
rigTranscript rig-live-rej-$$
sleep 1
printf 'wrong approach\nstart over' | rigOp "$rigTmp/v4" --member-review-reject magic-coordinator dispatch-20261008T1200Z-rej --from-stdin
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v4.rc" )" 0
rigAssert "the item is pending"                            "$( rigLoc dispatch-20261008T1200Z-rej )" pending
rigAssert "status review-rejected"                         "$( LC_ALL=C grep -c -x 'status: review-rejected' "$rigData/board/pending/dispatch-20261008T1200Z-rej.md" )" 1
rigAssert "DISMISSED went to the child's thread"           "$( rigPosts ):$( LC_ALL=C grep -c '"channel": *"CREJ00001"' "$rigTmp/bodies" )" 1:1
rigAssert "Decisions: verdict rejected, with the text"     "$( rigDecisions "$rigData/board/pending/dispatch-20261008T1200Z-rej.md" 'verdict: rejected: wrong approach start over' )" 1
rigAssert "transcript: VERDICT"                            "$( LC_ALL=C grep -c " VERDICT item=dispatch-20261008T1200Z-rej " "$rigTmp/tr-rig-live-rej-$$.log" )" 1

echo "-- 11. follow-up, then accept on the same item: the verdicts combine --"
rigItem review dispatch-20261008T1200Z-fu ""
printf -- '---\ntype: task\n---\n\nthe one imperfection left\n' | rigOp "$rigTmp/v5" --member-review-follow-up magic-coordinator dispatch-20261008T1200Z-fu task-20261008T1300Z-rig-follow --from-stdin
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v5.rc" )" 0
rigAssert "the new item is pending"                        "$( rigLoc task-20261008T1300Z-rig-follow )" pending
rigAssert "it carries follows-up"                          "$( LC_ALL=C grep -c -x 'follows-up: dispatch-20261008T1200Z-fu' "$rigData/board/pending/task-20261008T1300Z-rig-follow.md" )" 1
rigAssert "the original records the follow-up"             "$( rigDecisions "$rigData/board/review/dispatch-20261008T1200Z-fu.md" 'verdict: follow-up: task-20261008T1300Z-rig-follow' )" 1
rigOp "$rigTmp/v6" --member-review-accept magic-coordinator dispatch-20261008T1200Z-fu
rigAssert "and the original is then accepted"              "$( cat "$rigTmp/v6.rc" ):$( rigLoc dispatch-20261008T1200Z-fu )" 0:processed

## ---------------------------------------------------------------- a routine as review-by
echo "-- 12. a routine as review-by: listed by its own input scan, left alone by advance housekeeping --"
rigItem review dispatch-20261008T1200Z-gr1 "" 'review-by: grooming.routine
'
rigItem review dispatch-20261008T1200Z-gr2 "" 'review-by: magic-team.grooming.routine
'
rigItem review dispatch-20261008T1200Z-adv "" 'review-by: advance.routine
'
touch -t 202001010000 "$rigData"/board/review/dispatch-20261008T1200Z-gr1.md "$rigData"/board/review/dispatch-20261008T1200Z-gr2.md
rigOp "$rigTmp/s1" --magic-grooming-input-scan magic-coordinator
rigOp "$rigTmp/s2" --magic-advance-input-scan magic-coordinator
rigSection(){ LC_ALL=C awk -v want="$2" '$0 == want { on = 1 ; next ; } on && /^## / { exit ; } on' "$1" ; }
rigAssert "grooming lists both of its items"               "$( rigSection "$rigTmp/s1" '## review items addressed to grooming.routine' | LC_ALL=C grep -c -E '^- dispatch-20261008T1200Z-gr[12] ' )" 2
rigAssert "and not advance's"                              "$( rigSection "$rigTmp/s1" '## review items addressed to grooming.routine' | LC_ALL=C grep -c 'dispatch-20261008T1200Z-adv' )" 0
rigAssert "advance lists its own"                          "$( rigSection "$rigTmp/s2" '## review items addressed to advance.routine' | LC_ALL=C grep -c '^- dispatch-20261008T1200Z-adv ' )" 1
rigAssert "housekeeping keeps a routine reviewer, however old" "$( LC_ALL=C grep -c -x 'review-by: grooming.routine' "$rigData/board/review/dispatch-20261008T1200Z-gr1.md" )" 1

## ---------------------------------------------------------------- endings ordered by tooling
echo "-- 13. archive: the child dismissed, archived recorded --"
rigLive rig-live-arc-$$
rigRecord rig-live-arc-$$ spawn-started CARC00001:1700000000.000700 dispatch-20261008T1200Z-arc
rigItem review dispatch-20261008T1200Z-arc rig-live-arc-$$
rigTranscript rig-live-arc-$$
sleep 1
rigOp "$rigTmp/e1" --magic-grooming-to-archived magic-coordinator dispatch-20261008T1200Z-arc.md --from-state:review --owner-header-value keeper-myx
rigAssert "the move succeeds"                              "$( cat "$rigTmp/e1.rc" ):$( rigLoc dispatch-20261008T1200Z-arc )" 0:archived
rigAssert "DISMISSED went to the child"                    "$( LC_ALL=C grep -c '^END-DISMISS (archived): sent DISMISSED' "$rigTmp/e1" ):$( rigPosts )" 1:1
rigAssert "Decisions: dismissed archived"                  "$( rigDecisions "$rigData/board/archived/dispatch-20261008T1200Z-arc.md" 'dismissed: archived: sent DISMISSED' )" 1
rigAssert "transcript: ENDING"                             "$( LC_ALL=C grep -c " ENDING item=dispatch-20261008T1200Z-arc " "$rigTmp/tr-rig-live-arc-$$.log" )" 1

echo "-- 14. trash: the child dismissed and the ending recorded before the item goes --"
rigLive rig-live-tr-$$
rigRecord rig-live-tr-$$ spawn-started CTRA00001:1700000000.000800 dispatch-20261008T1200Z-tra
rigItem review dispatch-20261008T1200Z-tra rig-live-tr-$$
sleep 1
rigOp "$rigTmp/e2" --intern-op-board-trash magic-coordinator review dispatch-20261008T1200Z-tra.md
rigAssert "the trash succeeds"                             "$( cat "$rigTmp/e2.rc" ):$( rigLoc dispatch-20261008T1200Z-tra )" 0:not-found
rigAssert "DISMISSED went to the child"                    "$( rigPosts ):$( LC_ALL=C grep -c '"channel": *"CTRA00001"' "$rigTmp/bodies" )" 1:1
rigAssert "the trashed copy records the ending"            "$( rigDecisions "$rigData/trash/dispatch-20261008T1200Z-tra.md" 'dismissed: trashed: sent DISMISSED' )" 1

echo "-- 15. shutdown: every live child dismissed, recorded on its item --"
for rigPid in $rigLivePids ; do pkill -P "$rigPid" 2> /dev/null ; kill "$rigPid" 2> /dev/null ; done
rigLivePids=""
sleep 1
rigLive rig-live-sd1-$$
rigLive rig-live-sd2-$$
rigRecord rig-live-sd1-$$ spawn-started CSDA00001:1700000000.000900 dispatch-20261008T1200Z-sd1
rigRecord rig-live-sd2-$$ spawn-started CSDB00001:1700000000.001000 ""
rigItem running dispatch-20261008T1200Z-sd1 rig-live-sd1-$$
sleep 1
rigOp "$rigTmp/e3" --magic-review-shutdown magic-coordinator
rigAssert "the op succeeds"                                "$( cat "$rigTmp/e3.rc" )" 0
rigAssert "both live children were sent DISMISSED"         "$( LC_ALL=C grep -c -E "^SHUTDOWN: spawn rig-live-sd[12]-$$: sent keeper-myx" "$rigTmp/e3" ):$( LC_ALL=C grep -c -x 'SHUTDOWN: 2 of 2 live spawn(s) dismissed' "$rigTmp/e3" )" 2:1
rigAssert "the item records shutdown"                      "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-sd1.md" 'dismissed: shutdown: sent keeper-myx' )" 1

echo "-- 16. TaskStop: the process stopped as before, the ending recorded --"
for rigPid in $rigLivePids ; do pkill -P "$rigPid" 2> /dev/null ; kill "$rigPid" 2> /dev/null ; done
rigLivePids=""
rigLive rig-live-ts-$$
rigItem running dispatch-20261008T1200Z-ts rig-live-ts-$$
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4" TaskStop '{"task_id":"dispatch-20261008T1200Z-ts.md"}'
rigEnv=()
rigAssert "the process is stopped"                         "$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4" )" 1
rigAssert "Decisions: dismissed taskstop"                  "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-ts.md" 'dismissed: taskstop' )" 1

## ---------------------------------------------------------------- a return resumed natively
## From here the rig's console is the real template, run on a stub `claude` (first on PATH,
## never a real session): it answers --version and auth, logs each launch's argv, emits two
## stream-json lines and a handback mark, and fails a --fork-session launch while
## claude-resume-fails exists. The workspace selects claude-native.
rigTemplate="$rigLib/AgentsConsoleShellScript.template.sh"
[ -f "$rigTemplate" ] || rigRefuse "console template not found: $rigTemplate"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigWs/.local/MDLT.settings.env"
printf 'SPAWN_CLI_SERVICE=claude-native\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the real console template, on the rig stub claude\nexec bash "$RIG_TEMPLATE" "$@"\n' > "$rigWs/DistroAgentsConsole.sh"
printf '%s\n' '#!/bin/sh' \
	'case "$1" in --version) echo "9.9.9 (rig claude)" ; exit 0 ;; auth) echo "{\"loggedIn\":true}" ; exit 0 ;; esac' \
	'printf "%s\n" "$*" > "$RIG_TMP/claude-args.$$"' \
	'case " $* " in *" --fork-session "*) [ ! -f "$RIG_TMP/claude-resume-fails" ] || exit 1 ;; esac' \
	'printf "📦 SubagentHandback\n" >&2' \
	'printf "%s\n" "{\"type\":\"system\",\"subtype\":\"init\"}" "{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"rig\"}"' > "$rigTmp/bin/claude"
chmod +x "$rigTmp/bin/claude"
[ "$( PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" command -v claude )" = "$rigTmp/bin/claude" ] || rigRefuse "the stub claude is not first on the rig PATH"
rigCliSetting="claude-native+$( printf '9.9.9 (rig claude)\n' | LC_ALL=C cksum | LC_ALL=C awk '{ printf "%08x", $1 ; }' )"
## One returned item whose ended session is described by its record; the op, then its child awaited.
rigResume(){ ## case, record cli, record cli-setting, jsonl (yes|no)
	local rsOld="rig-old-$1" rsItem="dispatch-20261008T1400Z-$1"
	rigRsN=$(( ${rigRsN:-0} + 1 ))
	rigRecord "$rsOld" spawn-succeeded "CRS00001:1700000100.00010$rigRsN" "$rsItem" "trk-rs-$1" "cli: $2
cli-setting: $3
"
	rigItem review "$rsItem" "$rsOld"
	[ "$4" != yes ] || { mkdir -p "$rigTmp/.claude/projects/-rig-ws" && : > "$rigTmp/.claude/projects/-rig-ws/$rsOld.jsonl" ; }
	rm -f "$rigTmp"/claude-args.*
	rigEnv=( RIG_TEMPLATE="$rigTemplate" )
	rigOp "$rigTmp/rs-$1" --member-review-return magic-coordinator "$rsItem" --message "rs fix $1"
	rigEnv=()
	rigNew="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData"/board/*/"$rsItem.md" | head -1 )"
	rigWaitFor 40 test -f "$rigData/board/review/$rsItem.md"
	rigRsItem="$rigData/board/review/$rsItem.md"
}
rigArgsWith(){ LC_ALL=C grep -l -F -e "$1" "$rigTmp"/claude-args.* 2> /dev/null | wc -l | tr -d ' ' ; }

echo "-- 17. return to an ended claude-native session: resumed and forked, the corrections its only prompt --"
rigResume el claude-native "$rigCliSetting" yes
rigAssert "the op succeeds and says it resumes"            "$( cat "$rigTmp/rs-el.rc" ):$( LC_ALL=C grep -c '^RETURN: restarted keeper-myx on dispatch-20261008T1400Z-el, .*, resuming rig-old-el$' "$rigTmp/rs-el" )" 0:1
rigAssert "the new spawn records its cli and cli-setting"  "$( LC_ALL=C grep -h -c -x -e 'cli: claude-native' -e "cli-setting: $rigCliSetting" "$rigSpawned/trk-rs-el/$rigNew.md" )" 2
rigAssert "claude ran once, --resume old --fork-session --session-id new" "$( ls "$rigTmp"/claude-args.* | wc -l | tr -d ' ' ):$( rigArgsWith "--resume rig-old-el --fork-session --session-id $rigNew " )" 1:1
rigAssert "its prompt is the corrections and Decisions"    "$( rigArgsWith 'rs fix el' ):$( rigArgsWith '### Decisions (from dispatch-20261008T1400Z-el)' ):$( rigArgsWith '## Your sandbox' )" 1:1:0
rigAssert "Decisions: restart: resumed"                    "$( rigDecisions "$rigRsItem" 'review: restart: resumed \(from rig-old-el\)' ):$( rigDecisions "$rigRsItem" 'review: restart: new-process' )" 1:0
rigAssert "transcript: RESTART"                            "$( LC_ALL=C grep -h -c ' RESTART item=dispatch-20261008T1400Z-el kind=review ' "$rigData"/audit/*/session-*"${rigNew:0:8}"*.log 2> /dev/null | head -1 )" 1

echo "-- 18. each ineligible session falls back to a new process, the reason recorded --"
rigFallback(){ ## case, reason
	rigAssert "$1: says new process"                       "$( cat "$rigTmp/rs-$1.rc" ):$( LC_ALL=C grep -c -F "new process ($2)" "$rigTmp/rs-$1" )" 0:1
	rigAssert "$1: claude ran with no --resume, full brief" "$( rigArgsWith '--resume' ):$( rigArgsWith "--session-id $rigNew " ):$( rigArgsWith '## Your sandbox' )" 0:1:1
	rigAssert "$1: Decisions: restart: new-process"        "$( LC_ALL=C grep -c -F "review: restart: new-process ($2)" "$rigRsItem" )" 1
}
rigResume nc copilot-native "$rigCliSetting" yes
rigFallback nc 'the old session ran on copilot-native, not claude or claude-native'
rigResume cc claude "$rigCliSetting" yes
rigFallback cc 'the cli is now claude-native, the old session ran on claude'
rigResume cs claude-native "claude-native+00000000" yes
rigFallback cs 'the cli setting changed since the old session'
rigResume nj claude-native "$rigCliSetting" no
rigFallback nj 'the old session has no native transcript'
rigRecord rig-old-oh spawn-succeeded "CRS00001:1700000200.000100" "" trk-rs-oh "cli: claude-native
cli-setting: $rigCliSetting
"
LC_ALL=C sed -i.bak "s/^host: .*/host: rig-other-host/" "$rigSpawned/trk-rs-oh/rig-old-oh.md" && rm -f "$rigSpawned/trk-rs-oh/rig-old-oh.md.bak"
mkdir -p "$rigTmp/.claude/projects/-rig-ws" && : > "$rigTmp/.claude/projects/-rig-ws/rig-old-oh.jsonl"
rigRun "$rigTmp/rs-oh" bash -c '. "$1" ; . "$2" ; AgentsReviewResumeEligible "$3"' rig "$rigFn" "$rigLib/AgentsTools.ReviewFlow.include" "$rigSpawned/trk-rs-oh/rig-old-oh.md"
rigAssert "another host is ineligible"                     "$( cat "$rigTmp/rs-oh.rc" ):$( LC_ALL=C grep -c -F "the old session ran on host rig-other-host, not $rigHost" "$rigTmp/rs-oh" )" 1:1
## A live session is never restarted -- a return delivers to it -- so its reason is checked directly.
rigLive rig-old-lv-$$
rigRecord rig-old-lv-$$ spawn-started "CRS00001:1700000300.000100" "" trk-rs-lv "cli: claude-native
cli-setting: $rigCliSetting
"
: > "$rigTmp/.claude/projects/-rig-ws/rig-old-lv-$$.jsonl"
sleep 1
rigRun "$rigTmp/rs-lv" bash -c '. "$1" ; . "$2" ; AgentsReviewResumeEligible "$3"' rig "$rigFn" "$rigLib/AgentsTools.ReviewFlow.include" "$rigSpawned/trk-rs-lv/rig-old-lv-$$.md"
rigAssert "a live session is ineligible"                   "$( cat "$rigTmp/rs-lv.rc" ):$( LC_ALL=C grep -c -F 'the old session is still running' "$rigTmp/rs-lv" )" 1:1

echo "-- 19. a resume failing before its first event falls back, once, to a new process --"
: > "$rigTmp/claude-resume-fails"
rigResume rf claude-native "$rigCliSetting" yes
rm -f "$rigTmp/claude-resume-fails"
rigAssert "the op said it resumes"                         "$( cat "$rigTmp/rs-rf.rc" ):$( LC_ALL=C grep -c 'resuming rig-old-rf$' "$rigTmp/rs-rf" )" 0:1
rigAssert "claude ran twice: the resume, then one new process" "$( ls "$rigTmp"/claude-args.* | wc -l | tr -d ' ' ):$( rigArgsWith '--fork-session' ):$( rigArgsWith "--session-id $rigNew " ):$( rigArgsWith '## Your sandbox' )" 2:1:2:1
rigAssert "Decisions: new-process, never resumed"          "$( LC_ALL=C grep -c -F 'review: restart: new-process (the resume of rig-old-rf exited 1 before its first event)' "$rigRsItem" ):$( rigDecisions "$rigRsItem" 'review: restart: resumed' )" 1:0
rigAssert "transcript: RESTART"                            "$( LC_ALL=C grep -h -c ' RESTART item=dispatch-20261008T1400Z-rf kind=review ' "$rigData"/audit/*/session-*"${rigNew:0:8}"*.log 2> /dev/null | head -1 )" 1

echo "-- 20. who gives a verdict: the reviewer review-by names, as itself; the coordinator of last resort --"
rigReviewItem(){ ## item stem, review-by value
	rigItem review "$1" "" "review-by: $2
"
}
rigReviewItem dispatch-20261008T1500Z-vm keeper-myx
rigOp "$rigTmp/va1" --member-review-accept magic-tester dispatch-20261008T1500Z-vm
rigAssert "another member gives no verdict"                "$( cat "$rigTmp/va1.rc" ):$( rigLoc dispatch-20261008T1500Z-vm ):$( LC_ALL=C grep -c 'is reviewed by keeper-myx' "$rigTmp/va1" )" 1:review:1
rigOp "$rigTmp/va2" --member-review-reject magic-coordinator dispatch-20261008T1500Z-vm --message "not its call"
rigAssert "nor magic-coordinator through the member op"    "$( cat "$rigTmp/va2.rc" ):$( rigLoc dispatch-20261008T1500Z-vm )" 1:review
rigEnv=( MDAT_SPAWN_AGENT=magic-tester )
rigOp "$rigTmp/va3" --member-review-accept keeper-myx dispatch-20261008T1500Z-vm
rigEnv=()
rigAssert "a session naming the reviewer is refused"       "$( cat "$rigTmp/va3.rc" ):$( rigLoc dispatch-20261008T1500Z-vm )" 1:review
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx )
rigOp "$rigTmp/va4" --member-review-accept keeper-myx dispatch-20261008T1500Z-vm
rigEnv=()
rigAssert "the reviewer's own session accepts"             "$( cat "$rigTmp/va4.rc" ):$( rigLoc dispatch-20261008T1500Z-vm )" 0:processed
rigReviewItem dispatch-20261008T1500Z-vc keeper-myx
rigOp "$rigTmp/vc1" --magic-review-accept keeper-myx dispatch-20261008T1500Z-vc
rigAssert "the last-resort op runs as magic-coordinator only" "$( cat "$rigTmp/vc1.rc" ):$( rigLoc dispatch-20261008T1500Z-vc )" 1:review
rigOp "$rigTmp/vc2" --magic-review-accept magic-coordinator dispatch-20261008T1500Z-vc --summary "last resort"
rigAssert "magic-coordinator, reviewer of last resort"     "$( cat "$rigTmp/vc2.rc" ):$( rigLoc dispatch-20261008T1500Z-vc ):$( rigDecisions "$rigData/board/processed/dispatch-20261008T1500Z-vc.md" 'verdict: accepted: last resort' )" 0:processed:1
rigReviewItem dispatch-20261008T1500Z-vh human-owner
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx )
rigOp "$rigTmp/vh1" --member-review-accept keeper-myx dispatch-20261008T1500Z-vh
rigEnv=()
rigAssert "a human-owner item: no spawned session"         "$( cat "$rigTmp/vh1.rc" ):$( rigLoc dispatch-20261008T1500Z-vh )" 1:review
rigOp "$rigTmp/vh2" --member-review-accept human-owner dispatch-20261008T1500Z-vh
rigAssert "the human, at the console"                      "$( cat "$rigTmp/vh2.rc" ):$( rigLoc dispatch-20261008T1500Z-vh )" 0:processed
rigReviewItem dispatch-20261008T1500Z-vs rig-rev-session
rigReviewItem dispatch-20261008T1500Z-vs2 rig-rev-session
rigEnv=( MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-other-session )
rigOp "$rigTmp/vs1" --member-review-accept magic-tester dispatch-20261008T1500Z-vs2
rigEnv=()
rigAssert "a session reviewer: another session is refused" "$( cat "$rigTmp/vs1.rc" ):$( rigLoc dispatch-20261008T1500Z-vs2 )" 1:review
rigEnv=( MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-rev-session )
rigOp "$rigTmp/vs2" --member-review-accept magic-tester dispatch-20261008T1500Z-vs
rigEnv=()
rigAssert "that session itself accepts"                    "$( cat "$rigTmp/vs2.rc" ):$( rigLoc dispatch-20261008T1500Z-vs )" 0:processed
printf -- '---\nexecutors: keeper-myx\nmaintainers: magic-coordinator\n---\n# rig routine\n' > "$rigWs/.local/agents/members/keeper-myx/keeper-myx.rigcheck.routine.md"
rigReviewItem dispatch-20261008T1500Z-vr rigcheck.routine
rigOp "$rigTmp/vr1" --member-review-accept magic-tester dispatch-20261008T1500Z-vr
rigAssert "a routine reviewer: a non-executor is refused"  "$( cat "$rigTmp/vr1.rc" ):$( rigLoc dispatch-20261008T1500Z-vr )" 1:review
rigOp "$rigTmp/vr2" --member-review-accept keeper-myx dispatch-20261008T1500Z-vr
rigAssert "the routine's executor accepts"                 "$( cat "$rigTmp/vr2.rc" ):$( rigLoc dispatch-20261008T1500Z-vr )" 0:processed
rm -f "$rigWs/.local/agents/members/keeper-myx/keeper-myx.rigcheck.routine.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW FLOW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_FLOW: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
