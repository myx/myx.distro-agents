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
## Offline: a fake `curl` first on PATH logs each Slack call and opens no socket; a ps beside
## it lists the rig's own runs only, the stand-in children under their own pids; a fake
## DistroAgentsConsole.sh stands in for the CLI; the board, sandboxes and workspace are this
## rig's own temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A scan or an iteration of the main loop starts the control thread of a session of its rig that is not finished: what was started is ended before the tree is removed.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mktemp -d -t AgentsReviewFlowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/board/pending" \
	"$rigWs/.local/.agents" "$rigSpawned" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
## THE RIG'S OWN PROCESS LIST. A spawn is found running by a process list read from the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own, and another copy of this check for its own. So the ps
## first on PATH answers the whole-host listing from the rig's own list, beside it, one
## `<pid> <command line>` line a process, and hands every other call to the real ps. Each line
## is a stand-in process of this rig under its own pid, and is listed only while that process
## lives: one that is stopped is gone from the list, as it would be from the host's. Which
## process started which (pid and ppid alone) is asked of the real ps: it holds no id to match.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
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
rigItem(){ ## state, item stem, spawn-id or empty, extra frontmatter lines (may be empty) -- reviewed by magic-coordinator where those lines name no reviewer
	local itemReviewer="review-by: magic-coordinator
"
	case "${4:-}" in *review-by:*) itemReviewer="" ;; esac
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\n%s%s%s---\n\n# rig dispatch\n' "${3:+spawn-id: $3
}" "$itemReviewer" "${4:-}" > "$rigData/board/$1/$2.md"
}
rigRecord(){ ## spawn-id, status, session-thread or empty, item stem or empty, folder (default: spawn-id), extra lines
	local recFolder="${5:-$1}"
	mkdir -p "$rigSpawned/$recFolder"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n%s%s%s---\n' \
		"$1" "$1" "$recFolder" "$rigHost" "$2" "${3:+session-thread: $3
}" "${4:+spawns: $4
}" "${6:-}" > "$rigSpawned/$recFolder/$1.md"
}
rigLive(){ ## spawn-id -- a stand-in process, in the rig's process list under its own pid, running as the spawn id
	bash -c 'sleep 300 ; :' "$1" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	printf '%s rig-run --session-id %s\n' "$!" "$1" >> "$rigTmp/ps.list"
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
## The parent runs: the session it founded has its executor there to take the handback.
rigLive rig-par-1
rigRecord rig-child-1 spawn-started "" dispatch-20261008T1200Z-hb rig-child-1 'parent-spawn-id: rig-par-1
parent-session-id: rig-par-1
'
## parent-spawn-id is set twice above; the first one wins for every reader, so rewrite it.
LC_ALL=C sed -i.bak 's/^parent-spawn-id: none$/parent-spawn-id: rig-par-1/' "$rigSpawned/rig-child-1/rig-child-1.md" && rm -f "$rigSpawned/rig-child-1/rig-child-1.md.bak"
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
LC_ALL=C sed -i.bak 's/^parent-spawn-id: none$/parent-spawn-id: rig-par-rq/' "$rigSpawned/rig-child-rqp/rig-child-rqp.md" && rm -f "$rigSpawned/rig-child-rqp/rig-child-rqp.md.bak"
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

echo "-- 5. a --wait pass ended, its parent with no thread: review as wait-pass-ended, and where its handback goes --"
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
## The child joined its parent's session, and its spawn opened that session's thread: the
## parent's own from then on, so the handback goes there, not to another session's thread.
rigThread5="$( cat "$rigWs/.local/agents/sessions/rig-par-nothread/session.thread" 2> /dev/null )"
rigAssert "the child's parent-thread is the session thread its spawn opened for its parent's session" \
	"$( [ -n "$rigThread5" ] && printf opened || printf none ):$( LC_ALL=C grep -h -c -x "parent-thread: ${rigThread5:-none}" "$rigSpawned"/*/"$rigSpawn5.md" )" "opened:1"
## Only a parent whose session has no thread at all leaves the handback magic-coordinator's:
## here the child starts a session of its own, so nothing opens one for its parent.
rigRecord rig-par-nothread-b spawn-started "" "" rig-par-nothread-b
rigEnv=( MDAT_SPAWN_SESSION_ID=rig-par-nothread-b )
rigRun "$rigTmp/p5b" bash -c 'printf "rig brief" | bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:create --wait --session-new' "$rigFn"
rigEnv=()
rigItem5b="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/p5b" | head -1 )" ; rigItem5b="${rigItem5b%.md}"
rigSpawn5b="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigData/board/review/$rigItem5b.md" 2> /dev/null | head -1 )"
rigAssert "a child in a session of its own, its parent's session with no thread: the parent-thread is magic-coordinator's" \
	"$( [ -e "$rigWs/.local/agents/sessions/rig-par-nothread-b/session.thread" ] && printf opened || printf none ):$( LC_ALL=C grep -h -c -x 'parent-thread: CCOORD001:1700000000.000200' "$rigSpawned"/*/"${rigSpawn5b:-none}.md" 2> /dev/null )" "none:1"
## The child's handback to session-parent now has somewhere to go.
rigItem running dispatch-20261008T1200Z-fb rig-child-fb
rigLive rig-par-nothread
rigRecord rig-child-fb spawn-started "" dispatch-20261008T1200Z-fb rig-child-fb 'parent-thread: CCOORD001:1700000000.000200
parent-session-id: rig-par-nothread
'
LC_ALL=C sed -i.bak 's/^parent-spawn-id: none$/parent-spawn-id: rig-par-nothread/' "$rigSpawned/rig-child-fb/rig-child-fb.md" && rm -f "$rigSpawned/rig-child-fb/rig-child-fb.md.bak"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-child-fb )
rigTool "$rigTmp/h5" SubagentHandback '{"outcome":"fallback done"}'
rigEnv=()
## The parent session has a thread by now, opened by the first member it brought in (above): the
## handback goes there, where it reports to, and the parent-thread its spawn kept is read no more.
rigFbThread="$( cat "$rigWs/.local/agents/sessions/rig-par-nothread/session.thread" 2> /dev/null )"
rigAssert "the handback posts, no thread error, in the thread its parent session has"            "$( LC_ALL=C grep -c 'has no recorded thread' "$rigTmp/h5" ):$( [ -n "$rigFbThread" ] && LC_ALL=C grep -c "\"channel\": *\"${rigFbThread%%:*}\"" "$rigTmp/bodies" )" 0:1
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
## The run it replaces was brought into its caller's own session, rig-par-rst, whose thread is recorded for it.
rigRecord rig-ended-ret spawn-succeeded CEND00001:1700000000.000500 dispatch-20261008T1200Z-rst trk-rig-rst 'start-context: inline
parent-session-id: rig-par-rst
parent-member: magic-tester
'
mkdir -p "$rigWs/.local/agents/sessions/rig-par-rst" && printf '%s\n' CPRS00001:1700000000.000550 > "$rigWs/.local/agents/sessions/rig-par-rst/session.thread"
rigItem review dispatch-20261008T1200Z-rst rig-ended-ret
rigOp "$rigTmp/v3" --member-review-return magic-coordinator dispatch-20261008T1200Z-rst --message "redo the rig step"
rigAssert "the op succeeds"                                "$( cat "$rigTmp/v3.rc" )" 0
rigAssert "it says it restarted the session"               "$( LC_ALL=C grep -c '^RETURN: restarted keeper-myx on dispatch-20261008T1200Z-rst' "$rigTmp/v3" )" 1
rigNewRecord="$( for rigCandidate in "$rigSpawned/trk-rig-rst"/*.md ; do [ "${rigCandidate##*/}" = rig-ended-ret.md ] || printf '%s\n' "$rigCandidate" ; done | head -1 )"
rigAssert "a new spawn joined the same sandbox"            "$( [ -n "$rigNewRecord" ] && LC_ALL=C grep -c -x 'spawned-by: dispatch-20261008T1200Z-rst' "$rigNewRecord" )" 1
rigAssert "it carries the start context and the parent session of the run it replaces" \
	"$( LC_ALL=C sed -n -e 's/^start-context: //p' -e 's/^parent-session-id: //p' "$rigNewRecord" | tr '\n' ' ' )" "inline rig-par-rst "
rigAssert "it names the run it replaces, whose seat in the session it takes over" "$( LC_ALL=C sed -n 's/^restarted-from: //p' "$rigNewRecord" )" rig-ended-ret
rigNewSpawn="${rigNewRecord##*/}" ; rigNewSpawn="${rigNewSpawn%.md}"
rigWaitFor 20 test -s "$rigTmp/console-in.$rigNewSpawn"
rigAssert "its brief carries the corrections"              "$( LC_ALL=C grep -c -x 'redo the rig step' "$rigTmp/console-in.$rigNewSpawn" )" 1
rigAssert "and the item's Decisions first"                 "$( LC_ALL=C grep -c '^### Decisions (from dispatch-20261008T1200Z-rst)' "$rigTmp/console-in.$rigNewSpawn" )" 1
rigAssert "the item names the new spawn"                   "$( LC_ALL=C grep -h -c -x "spawn-id: $rigNewSpawn" "$rigData"/board/*/dispatch-20261008T1200Z-rst.md )" 1
rigWaitFor 40 test -f "$rigData/board/review/dispatch-20261008T1200Z-rst.md"
rigAssert "it ends with no handback, so back to review"    "$( rigLoc dispatch-20261008T1200Z-rst )" review
: > "$rigTmp/calls" ; : > "$rigTmp/bodies"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID="$rigNewSpawn" )
rigTool "$rigTmp/v3h" SubagentHandback '{"outcome":"redone","to":"session-parent"}'
rigEnv=()
rigAssert "its handback to session-parent reaches the thread of the session that started the run it replaces" \
	"$( LC_ALL=C grep -c 'no recorded parent session' "$rigTmp/v3h" ):$( LC_ALL=C grep -c '"channel": *"CPRS00001"' "$rigTmp/bodies" )" 0:1

rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include" )"
echo "-- 9d. return to an ended run that had no parent session, made from inside another session: it has none again --"
rigRecord rig-ended-np spawn-succeeded CENP00001:1700000000.000570 dispatch-20261008T1200Z-np trk-rig-np 'start-context: spawned
'
rigItem review dispatch-20261008T1200Z-np rig-ended-np
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-reviewer-np MDAT_SESSION_ID=rig-reviewer-np-session )
rigOp "$rigTmp/v3np" --member-review-return magic-coordinator dispatch-20261008T1200Z-np --message "redo it once more"
rigEnv=()
rigNewRecord="$( for rigCandidate in "$rigSpawned/trk-rig-np"/*.md ; do [ "${rigCandidate##*/}" = rig-ended-np.md ] || printf '%s\n' "$rigCandidate" ; done | head -1 )"
rigAssert "restarted with no parent session and no address, whoever returned it" \
	"$( cat "$rigTmp/v3np.rc" ):$( [ -n "$rigNewRecord" ] && LC_ALL=C grep -c -e '^parent-session-id: ' -e "^$rigReportsTo: " "$rigNewRecord" )" "0:0"
rigWaitFor 40 test -f "$rigData/board/review/dispatch-20261008T1200Z-np.md"
rigWaitFor 20 sh -c '! LC_ALL=C grep -q "^status: spawn-started" "$0"' "$rigNewRecord"

echo "-- 9c. a matter with no recorded address falls to a live magic-coordinator of the session, never back to that coordinator --"
rigRunRecord(){ ## spawn-id, member, session-id
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nsession-thread: CSES9C001:1700000000.000900\n---\n' "$3" "$1" "$1" "$rigHost" "$2" > "$rigSpawned/$1/$1.md"
}
rigLive rig-coord-9c-$$ ; rigRunRecord rig-coord-9c-$$ magic-coordinator rig-sess-9c-$$
rigLive rig-help-9c-$$ ; rigRunRecord rig-help-9c-$$ keeper-myx rig-sess-9c-$$
## The human-owner's identity record, which an ask of him is addressed by.
mkdir -p "$rigWs/.local/agents/members/human-owner" && printf -- '---\nname: human-owner\nstatus: reference-only\n---\n' > "$rigWs/.local/agents/members/human-owner/SKILL.md"
mkdir -p "$rigWs/.local/agents/sessions/rig-sess-9c-$$" && printf '%s\n' CSES9C001:1700000000.000900 > "$rigWs/.local/agents/sessions/rig-sess-9c-$$/session.thread"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-help-9c-$$ MDAT_SESSION_ID=rig-sess-9c-$$ MDAT_SESSION_THREAD=CSES9C001:1700000000.000900 )
rigTool "$rigTmp/q9c" AskQuestion '{"question":"Which way first?","wait":false}'
rigEnv=()
rigAssert "a member's question with no target goes to the session's live magic-coordinator, in the session thread" \
	"$( LC_ALL=C grep -c '^ASK-RESULT: POSTED' "$rigTmp/q9c" ):$( LC_ALL=C grep -c '"channel": *"CSES9C001"' "$rigTmp/bodies" ):$( LC_ALL=C grep -c '"channel": *"URIGOWNER"' "$rigTmp/bodies" )" "1:1:0"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-coord-9c-$$ MDAT_SESSION_ID=rig-sess-9c-$$ MDAT_SESSION_THREAD=CSES9C001:1700000000.000900 )
rigTool "$rigTmp/q9c2" AskQuestion '{"question":"Which way first?","wait":false}'
rigEnv=()
rigAssert "the coordinator's own question with no recorded address: up to the human-owner, never back to itself" \
	"$( LC_ALL=C grep -c '^ASK-RESULT: POSTED' "$rigTmp/q9c2" ):$( LC_ALL=C grep -c '"channel": *"URIGOWNER"' "$rigTmp/bodies" ):$( LC_ALL=C grep -c '"channel": *"CSES9C001"' "$rigTmp/bodies" )" "1:1:0"

echo "-- 9e. where no address is recorded: the initiator, where it runs in the session; else its executor; else a live magic-coordinator; else the human-owner --"
rigRun9e(){ ## spawn-id, member, session-id, status, more lines
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: %s\nsession-thread: CSES9E001:1700000000.000910\n%s---\n' "$3" "$1" "$1" "$rigHost" "$2" "$4" "${5:-}" > "$rigSpawned/$1/$1.md"
}
rigAsk9e(){ ## result file -- the child's question with no target, wait:false
	rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-kid-9e-$$ MDAT_SESSION_ID=rig-sess-9e-$$ MDAT_SESSION_THREAD=CSES9E001:1700000000.000910 )
	rigTool "$1" AskQuestion "{\"question\":\"Which way first, for ${1##*/}?\",\"wait\":false}"
	rigEnv=()
}
rigAskedOf9e(){ ## result file -- where it was asked and of whom: the session thread and its addressee, or the human-owner
	if LC_ALL=C grep -q '"channel": *"URIGOWNER"' "$rigTmp/bodies" ; then printf 'human-owner' ; return 0 ; fi
	LC_ALL=C grep -q '"channel": *"CSES9E001"' "$rigTmp/bodies" || { printf 'nowhere' ; return 0 ; }
	for rigWho in magic-tester magic-architect magic-coordinator ; do LC_ALL=C grep -q -F -- "_${rigWho}_" "$rigTmp/bodies" && { printf 'session:%s' "$rigWho" ; return 0 ; } ; done
	printf 'session:nobody'
}
## The session: founded by magic-architect, its executor; the child brought in by magic-tester, its initiator.
for rigWho in magic-architect human-owner ; do
	[ -d "$rigWs/.local/agents/members/$rigWho" ] || { mkdir -p "$rigWs/.local/agents/members/$rigWho" && printf -- '---\nname: %s\n---\n' "$rigWho" > "$rigWs/.local/agents/members/$rigWho/SKILL.md" ; }
done
rigRun9e rig-sess-9e-$$ magic-architect rig-sess-9e-$$ spawn-started
rigRun9e rig-init-9e-$$ magic-tester rig-sess-9e-$$ spawn-started
rigRun9e rig-kid-9e-$$ keeper-myx rig-sess-9e-$$ spawn-started 'parent-session-id: rig-sess-9e-'"$$"'
parent-member: magic-tester
'
mkdir -p "$rigWs/.local/agents/sessions/rig-sess-9e-$$" && printf '%s\n' CSES9E001:1700000000.000910 > "$rigWs/.local/agents/sessions/rig-sess-9e-$$/session.thread"
rigLive rig-sess-9e-$$ ; rigLive rig-init-9e-$$
rigAsk9e "$rigTmp/q9e1"
rigAssert "the initiator runs there: asked in the session thread, of it" "$( rigAskedOf9e )" "session:magic-tester"
## The initiator's run has ended, the executor's still runs.
LC_ALL=C sed -i.bak "/ rig-init-9e-$$\$/d" "$rigTmp/ps.list" && rm -f "$rigTmp/ps.list.bak"
rigAsk9e "$rigTmp/q9e2"
rigAssert "the initiator is gone: its session's executor takes it" "$( rigAskedOf9e )" "session:magic-architect"
## Neither runs; a magic-coordinator does, in that session.
LC_ALL=C sed -i.bak "/ rig-sess-9e-$$\$/d" "$rigTmp/ps.list" && rm -f "$rigTmp/ps.list.bak"
rigRun9e rig-coord-9e-$$ magic-coordinator rig-sess-9e-$$ spawn-started ; rigLive rig-coord-9e-$$
rigAsk9e "$rigTmp/q9e3"
rigAssert "neither runs: the live magic-coordinator of the session takes it" "$( rigAskedOf9e )" "session:magic-coordinator"
## Nobody runs there.
LC_ALL=C sed -i.bak "/ rig-coord-9e-$$\$/d" "$rigTmp/ps.list" && rm -f "$rigTmp/ps.list.bak"
rigAsk9e "$rigTmp/q9e4"
rigAssert "nobody runs there: the human-owner" "$( rigAskedOf9e )" "human-owner"

echo "-- 9f. a run that reports to no one: its handback is its report, in its own thread, moves nothing to review, and ends it --"
rigRecord rig-none-9f-$$ spawn-started CNON9F001:1700000000.000920 dispatch-20261008T1200Z-9f "" "$rigReportsTo: none
"
## Its item names no reviewer.
printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: rig-none-9f-%s\n---\n\n# rig dispatch\n' "$$" > "$rigData/board/running/dispatch-20261008T1200Z-9f.md"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-none-9f-$$ MDAT_SESSION_THREAD=CNON9F001:1700000000.000920 )
rigTool "$rigTmp/h9f" SubagentHandback '{"outcome":"the daily is done"}'
rigEnv=()
rigAssert "posted in its own session thread, as its report" "$( LC_ALL=C grep -c '"channel": *"CNON9F001"' "$rigTmp/bodies" ):$( LC_ALL=C grep -c '"channel": *"URIGOWNER"' "$rigTmp/bodies" )" "1:0"
rigAssert "its item stays where it was: nothing moved to review" "$( rigLoc dispatch-20261008T1200Z-9f )" running
rigAssert "and the run is ended on it: marked as one whose report is given" \
	"$( [ -f "$rigWs/.local/agents/sessions/rig-none-9f-$$/dismissed" ] && [ -f "$rigWs/.local/agents/sessions/rig-none-9f-$$/dismissed.handback" ] && printf ended ):$( LC_ALL=C grep -c 'end your run now' "$rigTmp/h9f" )" "ended:1"

echo "-- 9g. the item of a run that reports to no one, and names no reviewer, closes straight to processed --"
rigRun "$rigTmp/p9g" bash -c 'printf "rig brief" | bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:create --wait --reports-to none' "$rigFn"
rigItem9g="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/p9g" | head -1 )" ; rigItem9g="${rigItem9g%.md}"
rigAssert "processed, never in review, with no review in its Decisions" \
	"$( rigLoc "$rigItem9g" ):$( rigDecisions "$rigData/board/processed/$rigItem9g.md" 'review: none' )" "processed:1"
rigRun "$rigTmp/p9g2" bash -c 'printf "rig brief" | bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:create --wait --reports-to none --review-by magic-coordinator' "$rigFn"
rigItem9g2="$( LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$rigTmp/p9g2" | head -1 )" ; rigItem9g2="${rigItem9g2%.md}"
rigAssert "control: one that names a reviewer goes to review as before" "$( rigLoc "$rigItem9g2" )" review

echo "-- 9h. a run that reports to no one and founded its session ends on its report only once the others of that session have ended --"
rigRecord rig-none-9h-$$ spawn-started CNON9H001:1700000000.000930 "" "" "$rigReportsTo: none
"
mkdir -p "$rigSpawned/rig-part-9h-$$"
printf -- '---\nsession-id: rig-none-9h-%s\nspawn-id: rig-part-9h-%s\nparent-spawn-id: rig-none-9h-%s\nstart-context: joined\ntracking-name: rig-part-9h-%s\nhost: %s\nowner: magic-tester\nstatus: spawn-started\n---\n' \
	"$$" "$$" "$$" "$$" "$rigHost" > "$rigSpawned/rig-part-9h-$$/rig-part-9h-$$.md"
rigLive rig-part-9h-$$
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-none-9h-$$ MDAT_SESSION_THREAD=CNON9H001:1700000000.000930 )
rigTool "$rigTmp/h9h" SubagentHandback '{"outcome":"the routine is done"}'
rigAssert "its report is posted, and while a member it brought in runs it is not ended: told to wait" \
	"$( LC_ALL=C grep -c '"channel": *"CNON9H001"' "$rigTmp/bodies" ):$( [ -f "$rigWs/.local/agents/sessions/rig-none-9h-$$/dismissed" ] && printf ended || printf runs ):$( LC_ALL=C grep -c 'others of the session you founded still run' "$rigTmp/h9h" )" "1:runs:1"
LC_ALL=C sed -i.bak "/ rig-part-9h-$$\$/d" "$rigTmp/ps.list" && rm -f "$rigTmp/ps.list.bak"
rigTool "$rigTmp/w9h" Wait '{"sources":"slack:session-current","timeout":2}'
rigEnv=()
rigAssert "once that member has ended, its next Wait is its dismissal, its report given" \
	"$( LC_ALL=C grep -c -x 'WAIT-RESULT: DISMISSED' "$rigTmp/w9h" ):$( [ -f "$rigWs/.local/agents/sessions/rig-none-9h-$$/dismissed.handback" ] && printf given )" "1:given"

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
## The advance housekeeping runs when the routine takes its lock, free here, not in its scan.
rigAdvanceLock(){ ## result file -- the advance routine takes its lock
	rm -f "$rigData/inboxes/magic-coordinator/note-20260809T154715Z-advance-state-and-lock.md"
	rigOp "$1" --magic-advance-lock-acquire magic-coordinator rig-advance-pass
	[ "$( cat "$1.rc" )" = 0 ] || rigRefuse "the advance lock was not taken in the rig: $( tail -2 "$1" | LC_ALL=C tr '\n' ' ' )"
}
rigAdvanceLock "$rigTmp/s2l"
rigSection(){ LC_ALL=C awk -v want="$2" '$0 == want { on = 1 ; next ; } on && /^## / { exit ; } on' "$1" ; }
rigAssert "grooming lists both of its items"               "$( rigSection "$rigTmp/s1" '## review items addressed to grooming.routine' | LC_ALL=C grep -c -E '^- dispatch-20261008T1200Z-gr[12] ' )" 2
rigAssert "and not advance's"                              "$( rigSection "$rigTmp/s1" '## review items addressed to grooming.routine' | LC_ALL=C grep -c 'dispatch-20261008T1200Z-adv' )" 0
rigAssert "advance lists its own"                          "$( rigSection "$rigTmp/s2" '## review items addressed to advance.routine' | LC_ALL=C grep -c '^- dispatch-20261008T1200Z-adv ' )" 1
rigAssert "housekeeping keeps a routine reviewer, however old" "$( LC_ALL=C grep -c -x 'review-by: grooming.routine' "$rigData/board/review/dispatch-20261008T1200Z-gr1.md" )" 1

echo "-- 12b. a root session as review-by: ended only when its store says so, never by the age of the item --"
## A root session has no spawn record and no registry row: its store under .local/agents/sessions, and the
## marker its SessionEnd hook writes there, decide (AgentsToolsGrantsSessionEnded). An id with no store keeps the age rule.
rigRootLive="rig-root-live-$$" ; rigRootEnded="rig-root-ended-$$"
mkdir -p "$rigWs/.local/agents/sessions/$rigRootLive" "$rigWs/.local/agents/sessions/$rigRootEnded"
printf 'ended-at: 2026-10-09T12:00:00Z\nreason: prompt_input_exit\n' > "$rigWs/.local/agents/sessions/$rigRootEnded/ended"
rigItem review dispatch-20261008T1200Z-rl1 "" "review-by: $rigRootLive
"
rigItem review dispatch-20261008T1200Z-re1 "" "review-by: $rigRootEnded
"
rigItem review dispatch-20261008T1200Z-ns1 "" "review-by: rig-no-store-$$
"
touch -t 202001010000 "$rigData"/board/review/dispatch-20261008T1200Z-rl1.md "$rigData"/board/review/dispatch-20261008T1200Z-ns1.md
rigAdvanceLock "$rigTmp/s12b"
rigAssert "a root session still open keeps its review, however old the item" "$( LC_ALL=C grep -c -x "review-by: $rigRootLive" "$rigData/board/review/dispatch-20261008T1200Z-rl1.md" )" 1
rigAssert "a root session its SessionEnd hook ended hands its review on at once" "$( LC_ALL=C grep -c -x 'review-by: magic-coordinator' "$rigData/board/review/dispatch-20261008T1200Z-re1.md" )" 1
rigAssert "control: an id with no store at all still goes by age" "$( LC_ALL=C grep -c -x 'review-by: magic-coordinator' "$rigData/board/review/dispatch-20261008T1200Z-ns1.md" )" 1

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
rigProcSignalWithChildren TERM $rigLivePids
rigLivePids=""
: > "$rigTmp/ps.list"
sleep 1
rigLive rig-live-sd1-$$
rigLive rig-live-sd2-$$
rigRecord rig-live-sd1-$$ spawn-started CSDA00001:1700000000.000900 dispatch-20261008T1200Z-sd1
rigRecord rig-live-sd2-$$ spawn-started CSDB00001:1700000000.001000 ""
## A third record, still open, whose process is gone: its spawn id only stands on another
## process's command line, inside the path of its folder and quoted in its brief. A run is its
## own --session-id or --resume word alone, so it is no live child and is not dismissed.
rigRecord rig-held-sd3-$$ spawn-started CSDC00001:1700000000.001100 ""
bash -c 'sleep 300 ; :' rig-other > /dev/null 2>&1 < /dev/null &
rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
printf '%s claude --add-dir %s/rig-held-sd3-%s/input --session-id rig-other-run-%s --agent keeper-myx Readable %s/rig-held-sd3-%s/input, as said by --session-id rig-held-sd3-%s\n' "$!" "$rigSpawned" "$$" "$$" "$rigSpawned" "$$" "$$" >> "$rigTmp/ps.list"
disown "$!" 2> /dev/null || :
rigItem running dispatch-20261008T1200Z-sd1 rig-live-sd1-$$
sleep 1
rigOp "$rigTmp/e3" --magic-review-shutdown magic-coordinator
rigAssert "the op succeeds"                                "$( cat "$rigTmp/e3.rc" )" 0
rigAssert "both live children were sent DISMISSED"         "$( LC_ALL=C grep -c -E "^SHUTDOWN: spawn rig-live-sd[12]-$$: sent keeper-myx" "$rigTmp/e3" ):$( LC_ALL=C grep -c -x 'SHUTDOWN: 2 of 2 live spawn(s) dismissed' "$rigTmp/e3" )" 2:1
rigAssert "a spawn whose id only stands on another process's command line is no live child: nothing is said or sent for it" "$( LC_ALL=C grep -c -F "rig-held-sd3-$$" "$rigTmp/e3" )" 0
rigAssert "the item records shutdown"                      "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-sd1.md" 'dismissed: shutdown: sent keeper-myx' )" 1

echo "-- 16. TaskStop: the process stopped as before, the ending recorded --"
rigProcSignalWithChildren TERM $rigLivePids
rigLivePids=""
: > "$rigTmp/ps.list"
rigLive rig-live-ts-$$
rigItem running dispatch-20261008T1200Z-ts rig-live-ts-$$
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4" TaskStop '{"task_id":"dispatch-20261008T1200Z-ts.md"}'
rigEnv=()
rigAssert "the process is stopped"                         "$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4" )" 1
rigAssert "Decisions: dismissed taskstop"                  "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-ts.md" 'dismissed: taskstop' )" 1
## A run of a CLI that is given no session word: no line of the rig's process list runs as it,
## and its record names the process its launch started (`run-process: <pid> <start>`). A
## stand-in console with a child of its own, never a real CLI: TaskStop stops that process and
## what it started. A recorded pid that another process has taken, begun at another time, is
## never signalled.
rigStandIn(){ ## -- starts the stand-in; sets rigStandPid, rigStandChild and rigStandStart (when it began, as one word)
	local standLeft=40
	rm -f "$rigTmp/stand.child"
	bash -c 'sleep 300 > /dev/null 2>&1 < /dev/null & echo "$!" > "$1" ; wait' rig-stand "$rigTmp/stand.child" > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	disown "$!" 2> /dev/null || :
	while [ "$standLeft" -gt 0 ] && [ ! -s "$rigTmp/stand.child" ] ; do sleep 0.25 ; standLeft=$(( standLeft - 1 )) ; done
	rigStandChild="$( cat "$rigTmp/stand.child" 2> /dev/null )" ; rigProcNote $rigStandChild
	rigStandStart="$( LC_ALL=C ps -o lstart= -p "$rigStandPid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	[ -n "$rigStandChild" ] && [ -n "$rigStandStart" ] || rigRefuse "the stand-in console did not start, so nothing below would be measured"
}
rigAlive(){ ## pid... -- how many of them are still running
	local aliveCount=0 alivePid
	for alivePid in "$@" ; do ! kill -0 "$alivePid" 2> /dev/null || aliveCount=$(( aliveCount + 1 )) ; done
	printf '%s' "$aliveCount"
}
rigStandIn
rigRecord rig-noword-ts-$$ spawn-started "" dispatch-20261008T1200Z-nwts "" "run-process: $rigStandPid $rigStandStart
"
rigItem running dispatch-20261008T1200Z-nwts rig-noword-ts-$$
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4n" TaskStop '{"task_id":"dispatch-20261008T1200Z-nwts.md"}'
rigEnv=()
rigAssert "control: no line of the rig's process list runs as that spawn, or holds its id" "$( LC_ALL=C grep -c -F -- "rig-noword-ts-$$" "$rigTmp/ps.list" )" 0
rigAssert "a run with no session word is stopped: the process its record names, and what it started" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4n" ):$( rigAlive "$rigStandPid" "$rigStandChild" )" 1:0
rigAssert "and its item records the ending"                "$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-nwts.md" 'dismissed: taskstop' )" 1
rigAssert "its result says what is true of such a run: the process it was started as is no longer running, and nothing of a session id on a process list" \
	"$( LC_ALL=C grep -c -F 'TERM was sent to pid(s) ' "$rigTmp/e4n" ):$( LC_ALL=C grep -c -F 'and the process this run was started as, which its spawn record names, is no longer running.' "$rigTmp/e4n" ):$( LC_ALL=C grep -c -F 'carries that session id' "$rigTmp/e4n" )" 1:1:0
rigAssert "control: a run with a session word is told as before" \
	"$( LC_ALL=C grep -c -F 'and the process list no longer carries that session id.' "$rigTmp/e4" ):$( LC_ALL=C grep -c -F 'the process this run was started as' "$rigTmp/e4" )" 1:0
rigStandIn
rigRecord rig-noword-reused-$$ spawn-started "" dispatch-20261008T1200Z-nwru "" "run-process: $rigStandPid Mon_Jan__1_00:00:00_2001
"
rigItem running dispatch-20261008T1200Z-nwru rig-noword-reused-$$
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4r" TaskStop '{"task_id":"dispatch-20261008T1200Z-nwru.md"}'
rigEnv=()
rigAssert "a recorded pid that another process has taken is never signalled: nothing is stopped, and that process and its child live on" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: NO-PROCESS' "$rigTmp/e4r" ):$( rigAlive "$rigStandPid" "$rigStandChild" )" 1:2
rigProcSignal TERM "$rigStandChild" "$rigStandPid"
## A run with no tracking item: its spawn record alone names it. TaskStop given the spawn's own
## id stops it by the one rule a run is recognised by (the process whose own --session-id or
## --resume word is that id, or the process its record names) and says there was no item to
## record the stop on. A line that holds the id inside another word, and a command line of the
## tooling that names it, are no run of it and are never signalled.
rigStandInWord(){ ## command line text -- a stand-in process listed under its own pid with that line; sets rigWordPid
	bash -c 'sleep 300 ; :' rig-word > /dev/null 2>&1 < /dev/null &
	rigWordPid=$!
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	printf '%s %s\n' "$!" "$1" >> "$rigTmp/ps.list"
	disown "$!" 2> /dev/null || :
}
rigBoardSum(){ find "$rigData/board" -type f -exec cksum {} + 2> /dev/null | LC_ALL=C sort | cksum ; }
rigStandInWord "rig-run --session-id rig-noitem-ts-$$"
rigNoItemPid="$rigWordPid"
rigRecord rig-noitem-ts-$$ spawn-started "" ""
rigStandInWord "claude --add-dir $rigSpawned/rig-noitem-ts-$$/input --session-id rig-noitem-other-$$ --agent keeper-myx Readable $rigSpawned/rig-noitem-ts-$$/input, as said by --session-id rig-noitem-ts-$$"
rigNoItemOther="$rigWordPid"
rigStandInWord "bash $rigFn --intern-op-rig keeper-myx --session-id rig-noitem-ts-$$"
rigNoItemTooling="$rigWordPid"
rigBoardWas="$( rigBoardSum )"
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4u" TaskStop "{\"task_id\":\"rig-noitem-ts-$$\"}"
rigEnv=()
rigAssert "a run with no tracking item is stopped by its own id" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4u" ):$( LC_ALL=C grep -c '^ERROR' "$rigTmp/e4u" ):$( rigAlive "$rigNoItemPid" )" 1:0:0
rigAssert "its result says plainly that there was no item to record the stop on, and names its spawn record" \
	"$( LC_ALL=C grep -c -F "No dispatch item names session rig-noitem-ts-$$ as its own run, so there is no item to record a stop on." "$rigTmp/e4u" ):$( LC_ALL=C grep -c -F "$rigSpawned/rig-noitem-ts-$$/rig-noitem-ts-$$.md" "$rigTmp/e4u" ):$( LC_ALL=C grep -c -F 'Dispatch item ' "$rigTmp/e4u" )" 1:1:0
rigAssert "and nothing on the board is written"            "$( rigBoardSum )" "$rigBoardWas"
rigAssert "a line holding that id inside another word or in its text, and a tooling command line naming it, are no run of it: neither is signalled" \
	"$( rigAlive "$rigNoItemOther" "$rigNoItemTooling" )" 2
rigProcSignal TERM "$rigNoItemOther" "$rigNoItemTooling"
rigStandIn
rigRecord rig-noitem-noword-$$ spawn-started "" "" "" "run-process: $rigStandPid $rigStandStart
"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4v" TaskStop "{\"task_id\":\"rig-noitem-noword-$$\"}"
rigEnv=()
rigAssert "with no item and no session word, the process its record names is stopped, and what it started, and the result says both" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4v" ):$( rigAlive "$rigStandPid" "$rigStandChild" ):$( LC_ALL=C grep -c -F 'so there is no item to record a stop on.' "$rigTmp/e4v" ):$( LC_ALL=C grep -c -F 'and the process this run was started as, which its spawn record names, is no longer running.' "$rigTmp/e4v" )" 1:0:1:1
rigRecord rig-noitem-gone-$$ spawn-succeeded "" ""
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4g" TaskStop "{\"task_id\":\"rig-noitem-gone-$$\"}"
rigEnv=()
rigAssert "with no item and no live run of that id, nothing is signalled: NO-PROCESS, with the status its record holds" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: NO-PROCESS' "$rigTmp/e4g" ):$( LC_ALL=C grep -c -F 'status spawn-succeeded.' "$rigTmp/e4g" ):$( LC_ALL=C grep -c -F 'TERM' "$rigTmp/e4g" )" 1:1:0
## An id that no spawn record of this workspace names is no run of this team, whatever process
## of the host carries it as its own word: nothing is signalled.
rigStandInWord "rig-run --session-id rig-norecord-ts-$$"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4x" TaskStop "{\"task_id\":\"rig-norecord-ts-$$\"}"
rigEnv=()
rigAssert "control: an id no spawn record names is not reached, though a process runs as it" \
	"$( LC_ALL=C grep -c "^ERROR: no dispatch item matches handle rig-norecord-ts-$$ " "$rigTmp/e4x" ):$( LC_ALL=C grep -c '^STOP-RESULT' "$rigTmp/e4x" ):$( rigAlive "$rigWordPid" )" 1:0:1
rigProcSignal TERM "$rigWordPid"
## A spawn that joined a session: its item names the session as session-id and the spawn as
## spawn-id. Its own id reaches that item, and the stop is recorded there as for any item.
rigStandInWord "rig-run --session-id rig-join-ts-$$"
rigItem running dispatch-20261008T1200Z-jts rig-join-ts-$$ "session-id: rig-shared-ts-$$
"
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4j" TaskStop "{\"task_id\":\"rig-join-ts-$$\"}"
rigEnv=()
rigAssert "a spawn's own id reaches the item that names it as spawn-id: stopped, and recorded on that item" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4j" ):$( rigAlive "$rigWordPid" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-jts.md" 'dismissed: taskstop' ):$( LC_ALL=C grep -c -F "Dispatch item dispatch-20261008T1200Z-jts.md, session rig-join-ts-$$." "$rigTmp/e4j" ):$( LC_ALL=C grep -c -F 'no item to record' "$rigTmp/e4j" )" 1:0:1:1:0
## An item written before session-id and spawn-id were split names its own run as session-id
## and carries no spawn-id: that id reaches it as before.
rigStandInWord "rig-run --session-id rig-presplit-ts-$$"
rigItem running dispatch-20261008T1200Z-pts "" "session-id: rig-presplit-ts-$$
"
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4p" TaskStop "{\"task_id\":\"rig-presplit-ts-$$\"}"
rigEnv=()
rigAssert "control: an item that names its run as session-id alone is reached by that id as before: stopped, and recorded there" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4p" ):$( rigAlive "$rigWordPid" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-pts.md" 'dismissed: taskstop' ):$( LC_ALL=C grep -c -F "Dispatch item dispatch-20261008T1200Z-pts.md, session rig-presplit-ts-$$." "$rigTmp/e4p" )" 1:0:1:1
rigAssert "control: a run with an item is told of its item as before" \
	"$( LC_ALL=C grep -c -F "Dispatch item dispatch-20261008T1200Z-ts.md, session rig-live-ts-$$." "$rigTmp/e4" ):$( LC_ALL=C grep -c -F 'The dispatch item is closed by the spawn operation itself rather than here, so its status may still read as started for a moment.' "$rigTmp/e4" )" 1:1
## A founding spawn stopped through its item while two other participants of its session run. The
## command line of each participant holds the session folder, which carries the founding spawn's
## id, and a command line of the tooling names the session: none of them is the run the item
## names, and none is signalled.
rigStandInWord "claude --add-dir $rigSpawned/rig-found-ts-$$/input --session-id rig-found-ts-$$ --agent keeper-myx"
rigFoundPid="$rigWordPid"
rigStandInWord "claude --add-dir $rigSpawned/rig-found-ts-$$/input --session-id rig-part1-ts-$$ --agent magic-tester"
rigPart1Pid="$rigWordPid"
rigStandInWord "claude --add-dir $rigSpawned/rig-found-ts-$$/input --session-id rig-part2-ts-$$ --agent magic-tester"
rigPart2Pid="$rigWordPid"
rigStandInWord "bash $rigFn --intern-op-agent-spawn-proxy magic-tester --session-id rig-found-ts-$$"
rigFoundTooling="$rigWordPid"
rigItem running dispatch-20261008T1200Z-fts rig-found-ts-$$ "session-id: rig-found-ts-$$
"
rigItem running dispatch-20261008T1100Z-p1ts rig-part1-ts-$$ "session-id: rig-found-ts-$$
"
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4f" TaskStop '{"task_id":"dispatch-20261008T1200Z-fts.md"}'
rigEnv=()
rigAssert "a founding spawn stopped through its item: its own run alone is signalled, with the process it started, and the two other participants of its session and the tooling line stay alive" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4f" ):$( rigAlive "$rigFoundPid" ):$( rigAlive "$rigPart1Pid" "$rigPart2Pid" "$rigFoundTooling" ):$( LC_ALL=C grep -c -E "TERM was sent to pid\(s\) $rigFoundPid [0-9]+ and the process list no longer carries that session id\." "$rigTmp/e4f" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1200Z-fts.md" 'dismissed: taskstop' )" 1:0:3:1:1
## The id several participants share is the founding spawn's own: given as the handle it is the
## founding spawn's run that is asked for, and its item, never the first item on the board that
## holds the id, which here is a participant's.
rigStandInWord "claude --add-dir $rigSpawned/rig-found-ts-$$/input --session-id rig-found-ts-$$ --agent keeper-myx"
rigFoundPid="$rigWordPid"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4s" TaskStop "{\"task_id\":\"rig-found-ts-$$\"}"
rigEnv=()
rigAssert "a session id several participants share reaches the item of the run asked for, not the first on the board: the founding spawn is stopped, the participants live" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4s" ):$( LC_ALL=C grep -c -F "Dispatch item dispatch-20261008T1200Z-fts.md, session rig-found-ts-$$." "$rigTmp/e4s" ):$( rigAlive "$rigFoundPid" ):$( rigAlive "$rigPart1Pid" "$rigPart2Pid" "$rigFoundTooling" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1100Z-p1ts.md" 'dismissed: taskstop' )" 1:1:0:3:0
rigProcSignal TERM "$rigPart1Pid" "$rigPart2Pid" "$rigFoundTooling"
## A session id that items name only as the session they joined, with no run and no spawn record
## of its own: nothing says which participant is meant, so it is refused in one line that lists
## the items and says to name one.
rigStandInWord "claude --add-dir $rigSpawned/rig-lost-ts-$$/input --session-id rig-part3-ts-$$ --agent magic-tester"
rigPart3Pid="$rigWordPid"
rigStandInWord "claude --add-dir $rigSpawned/rig-lost-ts-$$/input --session-id rig-part4-ts-$$ --agent keeper-myx"
rigPart4Pid="$rigWordPid"
rigItem running dispatch-20261008T1100Z-p3ts rig-part3-ts-$$ "session-id: rig-lost-ts-$$
"
rigItem running dispatch-20261008T1100Z-p4ts rig-part4-ts-$$ "session-id: rig-lost-ts-$$
"
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4m" TaskStop "{\"task_id\":\"rig-lost-ts-$$\"}"
rigEnv=()
rigAssert "a shared session id that is no run of its own is refused in one line that lists the items and says to name one; nothing is signalled or recorded" \
	"$( LC_ALL=C grep -c -x -F "ERROR: rig-lost-ts-$$ is the session id of 2 dispatch item(s), and no item and no spawn record has it as its own run: dispatch-20261008T1100Z-p3ts.md (keeper-myx, spawn-id rig-part3-ts-$$), dispatch-20261008T1100Z-p4ts.md (keeper-myx, spawn-id rig-part4-ts-$$). Pass the filename of the one to stop, or its spawn-id, as task_id. Nothing was signalled." "$rigTmp/e4m" ):$( LC_ALL=C grep -c '^STOP-RESULT' "$rigTmp/e4m" ):$( rigAlive "$rigPart3Pid" "$rigPart4Pid" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1100Z-p3ts.md" 'dismissed: taskstop' )" 1:0:2:0
## The same id where a spawn record names it and no item is its own: the founding spawn's run is
## the one asked for, stopped with no item to record it on; the participant's item is left alone.
rigStandInWord "claude --add-dir $rigSpawned/rig-lost-ts-$$/input --session-id rig-lost-ts-$$ --agent keeper-myx"
rigLostPid="$rigWordPid"
rigRecord rig-lost-ts-$$ spawn-started "" ""
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4l" TaskStop "{\"task_id\":\"rig-lost-ts-$$\"}"
rigEnv=()
rigAssert "with a spawn record of that id and no item of its own, the founding spawn's run is stopped and said to have no item; the participants and their items are left alone" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4l" ):$( LC_ALL=C grep -c -F "No dispatch item names session rig-lost-ts-$$ as its own run, so there is no item to record a stop on." "$rigTmp/e4l" ):$( rigAlive "$rigLostPid" ):$( rigAlive "$rigPart3Pid" "$rigPart4Pid" ):$( rigDecisions "$rigData/board/running/dispatch-20261008T1100Z-p3ts.md" 'dismissed: taskstop' )" 1:1:0:2:0
rigProcSignal TERM "$rigPart3Pid" "$rigPart4Pid"
## A run with processes under it. A stop ends what the run started, to any depth, by the one walk
## the manager's kill uses too (AgentsToolsRegistryRunProcesses): its tool command and that
## command's own child. It never signals a process that runs as another spawn, nor the process that
## started that one and waits for it, though both stand under the run.
rigStandInKids(){ ## spawn id -- a stand-in run with a tool command that has a child, and a process whose child runs as another spawn; sets rigKidsPid, rigKidsTool, rigKidsDeep, rigKidsSuper and rigKidsOther
	local kidsLeft=40
	rm -f "$rigTmp/kids.tool" "$rigTmp/kids.deep" "$rigTmp/kids.super" "$rigTmp/kids.other"
	bash -c '
		bash -c "sleep 300 > /dev/null 2>&1 < /dev/null & echo \$! > \"\$1\" ; wait" rig-tool "$1.deep" > /dev/null 2>&1 < /dev/null &
		echo "$!" > "$1.tool"
		bash -c "sleep 300 > /dev/null 2>&1 < /dev/null & echo \$! > \"\$1\" ; wait" rig-super "$1.other" > /dev/null 2>&1 < /dev/null &
		echo "$!" > "$1.super"
		wait
	' rig-kids "$rigTmp/kids" > /dev/null 2>&1 < /dev/null &
	rigKidsPid=$!
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	disown "$!" 2> /dev/null || :
	while [ "$kidsLeft" -gt 0 ] && { [ ! -s "$rigTmp/kids.tool" ] || [ ! -s "$rigTmp/kids.deep" ] || [ ! -s "$rigTmp/kids.super" ] || [ ! -s "$rigTmp/kids.other" ] ; } ; do sleep 0.25 ; kidsLeft=$(( kidsLeft - 1 )) ; done
	rigKidsTool="$( cat "$rigTmp/kids.tool" 2> /dev/null )" ; rigKidsDeep="$( cat "$rigTmp/kids.deep" 2> /dev/null )"
	rigKidsSuper="$( cat "$rigTmp/kids.super" 2> /dev/null )" ; rigKidsOther="$( cat "$rigTmp/kids.other" 2> /dev/null )"
	[ -n "$rigKidsTool" ] && [ -n "$rigKidsDeep" ] && [ -n "$rigKidsSuper" ] && [ -n "$rigKidsOther" ] || rigRefuse "the stand-in run with its processes did not start, so nothing below would be measured"
	rigLivePids="$rigLivePids $rigKidsTool $rigKidsDeep $rigKidsSuper $rigKidsOther" ; rigProcNote $rigKidsTool $rigKidsDeep $rigKidsSuper $rigKidsOther
	printf '%s rig-run --session-id %s\n' "$rigKidsPid" "$1" >> "$rigTmp/ps.list"
	printf '%s claude --session-id rig-kids-other-%s --agent keeper-myx\n' "$rigKidsOther" "$$" >> "$rigTmp/ps.list"
}
rigStandInKids "rig-kids-ts-$$"
rigRecord rig-kids-ts-$$ spawn-started "" ""
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4k" TaskStop "{\"task_id\":\"rig-kids-ts-$$\"}"
rigEnv=()
rigAssert "a stop ends what the run started, to any depth: the run, its tool command and that command's own child are gone" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4k" ):$( rigAlive "$rigKidsPid" "$rigKidsTool" "$rigKidsDeep" )" 1:0
rigAssert "and never a process that runs as another spawn, nor the process that started that one and waits for it, though they stand under the run" \
	"$( rigAlive "$rigKidsSuper" "$rigKidsOther" )" 2
rigProcSignal TERM "$rigKidsOther" "$rigKidsSuper"
## A run whose tool command ignores the polite end. The run's own process ends on TERM, and then no
## walk from the run leads to that command any more. A stop keeps what it signalled, each process
## with when it began, and reads what is left by those processes themselves: without force its
## result says the command is still running, and with force the command gets the hard kill.
rigStandInHung(){ ## spawn id -- a stand-in run whose tool command ignores TERM; sets rigHungPid and rigHungTool
	local hungLeft=40
	rm -f "$rigTmp/hung.tool"
	bash -c 'perl -e '"'"'$SIG{TERM} = "IGNORE" ; open( my $rigSaid, ">", $ARGV[0] ) ; print $rigSaid "$$\n" ; close( $rigSaid ) ; sleep 300'"'"' "$1" > /dev/null 2>&1 < /dev/null & wait' rig-hung "$rigTmp/hung.tool" > /dev/null 2>&1 < /dev/null &
	rigHungPid=$!
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	disown "$!" 2> /dev/null || :
	while [ "$hungLeft" -gt 0 ] && [ ! -s "$rigTmp/hung.tool" ] ; do sleep 0.25 ; hungLeft=$(( hungLeft - 1 )) ; done
	rigHungTool="$( cat "$rigTmp/hung.tool" 2> /dev/null )"
	[ -n "$rigHungTool" ] || rigRefuse "the stand-in run with a tool command that ignores TERM did not start, so nothing below would be measured"
	rigLivePids="$rigLivePids $rigHungTool" ; rigProcNote "$rigHungTool"
	printf '%s rig-run --session-id %s\n' "$rigHungPid" "$1" >> "$rigTmp/ps.list"
}
rigStandInHung "rig-hung-ts-$$"
rigRecord rig-hung-ts-$$ spawn-started "" ""
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4h" TaskStop "{\"task_id\":\"rig-hung-ts-$$\"}"
rigEnv=()
rigAssert "a stop without force, of a run whose tool command ignores the polite end: the run's own process is gone, and the result says the command is still running, by its pid, and not that the run was stopped" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: STILL-RUNNING' "$rigTmp/e4h" ):$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4h" ):$( rigAlive "$rigHungPid" ):$( rigAlive "$rigHungTool" ):$( LC_ALL=C grep -c -E "and pid\(s\) $rigHungTool are still running two seconds later\. Nothing further was sent" "$rigTmp/e4h" )" 1:0:0:1:1
## What that stop left is kept in the run's own store, each process with when it began. So the next
## stop of that run finds the command, though it stands under no process of the run any more: with
## force, as the result of the first said to call it, the command gets the hard kill.
rigHungKept="$rigWs/.local/agents/sessions/rig-hung-ts-$$/stop.left"
rigAssert "what the stop left is kept in the run's store: the command, by its pid and when it began, and nothing else" \
	"$( LC_ALL=C awk 'END { print NR + 0 }' "$rigHungKept" 2> /dev/null ):$( LC_ALL=C awk -v wantPid="$rigHungTool" '$1 == wantPid && NF == 2 { hit++ } END { print hit + 0 }' "$rigHungKept" 2> /dev/null )" 1:1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4h2" TaskStop "{\"task_id\":\"rig-hung-ts-$$\",\"force\":true}"
rigEnv=()
rigAssert "a second call, with force, as the first result said: KILLED, the command is gone, and nothing is kept any more" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: KILLED' "$rigTmp/e4h2" ):$( LC_ALL=C grep -c '^STOP-RESULT: NO-PROCESS' "$rigTmp/e4h2" ):$( rigAlive "$rigHungTool" ):$( [ -e "$rigHungKept" ] && echo kept || echo cleared )" 1:0:0:cleared
rigProcSignal KILL "$rigHungTool"
rigStandInHung "rig-hung-force-$$"
rigRecord rig-hung-force-$$ spawn-started "" ""
sleep 1
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigTool "$rigTmp/e4i" TaskStop "{\"task_id\":\"rig-hung-force-$$\",\"force\":true}"
rigEnv=()
rigAssert "with force the command gets the hard kill: it is gone with the run, and the result says KILLED" \
	"$( LC_ALL=C grep -c '^STOP-RESULT: KILLED' "$rigTmp/e4i" ):$( LC_ALL=C grep -c '^STOP-RESULT: STOPPED' "$rigTmp/e4i" ):$( rigAlive "$rigHungPid" "$rigHungTool" )" 1:0:0
## The same pid begun at another time is another process: a stop never sends it the hard kill for the
## process it signalled. Held where the list of what a stop signalled is read (the manager's kill
## reads it by the same function): a kept line whose start is no longer the process's own gives nothing.
rigStandIn
rigAssert "a kept pid that another process has taken since is none of what is left: the same pid with another start gives nothing, and with its own start gives the pid" \
	"$( MMDAPP="$rigWs" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash -c '. "$1/AgentsTools.Registries.include" 2> /dev/null ; AgentsToolsRegistryRunLeft rig-no-such-run "$2 Mon_Jan__1_00:00:00_2001" - | tr "\n" " " ; printf "/ " ; AgentsToolsRegistryRunLeft rig-no-such-run "$2 $3" - | tr "\n" " "' rig-left "$rigLib" "$rigStandPid" "$rigStandStart" )" "/ $rigStandPid "
rigProcSignal TERM "$rigStandChild" "$rigStandPid"

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
rigAssert "the launcher kept the process it started on the new spawn's record, and the run closed as it ended" \
	"$( LC_ALL=C grep -c -E '^run-process: [0-9]+ [^ ]+$' "$rigSpawned/trk-rs-el/$rigNew.md" ):$( LC_ALL=C grep -c -x -e 'status: spawn-succeeded' -e 'exit-code: 0' "$rigSpawned/trk-rs-el/$rigNew.md" )" 1:2
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

echo "-- 21. a verdict comes back at once: a child it restarted, which never ends, does not hold its caller --"
## The caller reads the verdict's output through a pipe, as a tool call does: it sees the end
## when the operation ends, never when the child ends. Stdin is the file named in rigPipedIn.
rigPipedIn=/dev/null
rigPiped(){ ## result file, seconds allowed, DistroAgentsTools.fn.sh args... -> returned | waiting
	local pipedOut="$1" pipedLeft="$2" pipedPid ; shift 2
	( env -i HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c 'cd "$MMDAPP" && exec bash "$0" "$@"' "$rigFn" "$@" < "$rigPipedIn" 2>&1 | cat > "$pipedOut" ) &
	pipedPid=$!
	while kill -0 "$pipedPid" 2> /dev/null && [ "$pipedLeft" -gt 0 ] ; do sleep 1 ; pipedLeft=$(( pipedLeft - 1 )) ; done
	if kill -0 "$pipedPid" 2> /dev/null ; then
		printf 'waiting' ; kill "$pipedPid" 2> /dev/null
	else
		printf 'returned'
	fi
}
## The stub claude never ends: it says it started, leaves its pid, and stays.
printf '%s\n' '#!/bin/sh' \
	'case "$1" in --version) echo "9.9.9 (rig claude)" ; exit 0 ;; auth) echo "{\"loggedIn\":true}" ; exit 0 ;; esac' \
	'printf "%s\n" "{\"type\":\"system\",\"subtype\":\"init\"}"' \
	'echo "$$" > "$RIG_TMP/never.pid"' \
	'exec sleep 600' > "$rigTmp/bin/claude"
chmod +x "$rigTmp/bin/claude"
rigRecord rig-old-nv spawn-succeeded "CRS00001:1700000100.000199" dispatch-20261008T1600Z-nv trk-rs-nv "cli: claude-native
cli-setting: $rigCliSetting
"
rigItem review dispatch-20261008T1600Z-nv rig-old-nv
mkdir -p "$rigTmp/.claude/projects/-rig-ws" && : > "$rigTmp/.claude/projects/-rig-ws/rig-old-nv.jsonl"
rm -f "$rigTmp/never.pid"
## From inside a session, as a coordinator gives a verdict: the child is then detached.
rigEnv=( RIG_TEMPLATE="$rigTemplate" MDAT_SPAWN_SESSION_ID=rig-parent-nv MDAT_SPAWN_AGENT=magic-coordinator )
rigAssert "a return that restarts a child which never ends comes back to its caller" \
	"$( rigPiped "$rigTmp/nv" 40 --member-review-return magic-coordinator dispatch-20261008T1600Z-nv --message "redo the rig step" )" returned
rigAssert "with what it did"                               "$( LC_ALL=C grep -c '^RETURN: restarted keeper-myx on dispatch-20261008T1600Z-nv, .*, resuming rig-old-nv$' "$rigTmp/nv" )" 1
rigWaitFor 40 test -s "$rigTmp/never.pid"
rigNever="$( cat "$rigTmp/never.pid" 2> /dev/null )" ; rigProcNote $rigNever
rigAssert "while the child it restarted is still running"  "$( kill -0 "${rigNever:-0}" 2> /dev/null && printf running || printf gone )" running
## The other verdicts start no child: each returns at once beside a live one all the same.
for rigVerb in accept reject follow-up ; do
	rigLive "rig-live-nv-$rigVerb-$$"
	rigRecord "rig-live-nv-$rigVerb-$$" spawn-started CNV00001:1700000000.000900 "dispatch-20261008T1600Z-$rigVerb"
	rigItem review "dispatch-20261008T1600Z-$rigVerb" "rig-live-nv-$rigVerb-$$"
	rigTranscript "rig-live-nv-$rigVerb-$$"
done
sleep 1
rigAssert "accept comes back at once"                      "$( rigPiped "$rigTmp/nva" 40 --member-review-accept magic-coordinator dispatch-20261008T1600Z-accept --summary "good" ):$( rigLoc dispatch-20261008T1600Z-accept )" returned:processed
rigAssert "reject comes back at once"                      "$( rigPiped "$rigTmp/nvr" 40 --member-review-reject magic-coordinator dispatch-20261008T1600Z-reject --message "start over" ):$( rigLoc dispatch-20261008T1600Z-reject )" returned:pending
printf -- '---\ntype: task\n---\n\nthe one thing left\n' > "$rigTmp/nv.follow"
rigPipedIn="$rigTmp/nv.follow"
rigAssert "follow-up comes back at once"                   "$( rigPiped "$rigTmp/nvf" 40 --member-review-follow-up magic-coordinator dispatch-20261008T1600Z-follow-up task-20261008T1700Z-rig-nv --from-stdin ):$( rigLoc task-20261008T1700Z-rig-nv )" returned:pending
rigPipedIn=/dev/null
rigEnv=()
## The child is ended now, so its own close steps finish before this check leaves. A claude
## that ends at once and hands back stands in first: the close retries a child that ended
## with no handback, and that retry must not be one more child that never ends.
printf '%s\n' '#!/bin/sh' \
	'case "$1" in --version) echo "9.9.9 (rig claude)" ; exit 0 ;; auth) echo "{\"loggedIn\":true}" ; exit 0 ;; esac' \
	'printf "📦 SubagentHandback\n" >&2' \
	'printf "%s\n" "{\"type\":\"system\",\"subtype\":\"init\"}" "{\"type\":\"result\",\"subtype\":\"success\",\"result\":\"rig\"}"' > "$rigTmp/bin/claude"
[ -z "$rigNever" ] || rigProcSignal TERM "$rigNever"
rigWaitFor 60 test -f "$rigData/board/review/dispatch-20261008T1600Z-nv.md"
rigWaitFor 30 test ! -d "$rigSpawned/trk-rs-nv/input"
## Its sandbox input is read-only while it stands: writable again, so this check's tree can go.
chmod -R u+w "$rigSpawned/trk-rs-nv" 2> /dev/null || :

echo "-- 22. a brief for another agent over the plain-language floor is written and reported, never held back --"
rigLongText='one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twentyone twentytwo twentythree twentyfour twentyfive twentysix; with a semicolon.'
rigLive rig-live-fl-$$
rigRecord rig-live-fl-$$ spawn-started CFL00001:1700000000.000950 dispatch-20261008T1600Z-fl
rigItem review dispatch-20261008T1600Z-fl rig-live-fl-$$
rigTranscript rig-live-fl-$$
sleep 1
rigOp "$rigTmp/fl" --member-review-return magic-coordinator dispatch-20261008T1600Z-fl --message "$rigLongText"
rigAssert "a verdict's text to a child, over the floor, is delivered" "$( cat "$rigTmp/fl.rc" ):$( LC_ALL=C grep -c 'RETURN: delivered to keeper-myx in CFL00001' "$rigTmp/fl" ):$( LC_ALL=C grep -c 'twentysix; with a semicolon' "$rigTmp/bodies" )" 0:1:1
rigAssert "and its item carries it"                        "$( LC_ALL=C grep -c -x -F "$rigLongText" "$rigData/board/running/dispatch-20261008T1600Z-fl.md" )" 1
rigAssert "and it is never returned as a correction"       "$( LC_ALL=C grep -c '^CORRECTION' "$rigTmp/fl" )" 0
## The same text through the tooling's own send, and through a member's own: the first is
## sent and reported as over the floor, the second is held back for its sender to correct.
rigOp "$rigTmp/fl2" --intern-op-comms-slack-send-message magic-coordinator CFL00001:1700000000.000950 --identity-bot --address-to keeper-myx "$rigLongText"
rigAssert "a send of the tooling's own, over the floor, is sent and reported" \
	"$( cat "$rigTmp/fl2.rc" ):$( LC_ALL=C grep -c 'IT WAS WRITTEN ANYWAY' "$rigTmp/fl2" ):$( LC_ALL=C grep -c '^SENT_MESSAGE_TS=' "$rigTmp/fl2" ):$( LC_ALL=C grep -c '^CORRECTION' "$rigTmp/fl2" )" 0:1:1:0
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator )
rigOp "$rigTmp/fl3" --member-comms-slack-send-message magic-coordinator CFL00001:1700000000.000950 "$rigLongText"
rigEnv=()
rigAssert "a member's own send of the same text is not sent: a correction, with its own code" \
	"$( cat "$rigTmp/fl3.rc" ):$( LC_ALL=C grep -c '^CORRECTION: ' "$rigTmp/fl3" ):$( LC_ALL=C grep -c '^- word-cap: ' "$rigTmp/fl3" ):$( LC_ALL=C grep -c '^- semicolon: ' "$rigTmp/fl3" ):$( LC_ALL=C grep -c -x 'NEXT: rewrite the sentences or paragraphs named above and send the message again' "$rigTmp/fl3" ):$( rigPosts )" 6:1:1:1:1:0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW FLOW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_FLOW: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
