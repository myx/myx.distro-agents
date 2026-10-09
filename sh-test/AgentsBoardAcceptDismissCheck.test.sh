#!/usr/bin/env bash
## Behavioural check on accept releasing the child: --magic-board-to-processed moving an
## item whose spawn-id names a live spawn sends DISMISSED, addressed to that spawn's own
## member, into its session thread -- the message AgentsDismissalMatch.awk recognises, so
## the child's Wait returns WAIT-RESULT: DISMISSED. Every case where nothing can be sent
## still moves the item and says why. The stub is the coordinator's; the review flow calls its
## implementation, --intern-op-board-to-processed, for a member reviewer. A fake `curl` first on PATH logs each Slack call and
## opens no socket; the board, sandboxes and workspace are this rig's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
rigTmp="$( mktemp -d -t AgentsBoardAcceptDismissCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePid=""
trap '[ -z "$rigLivePid" ] || kill "$rigLivePid" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigData/board/review" "$rigData/board/processed" "$rigWs/.local/.agents" "$rigSpawned" "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The sender and the child as members of this rig workspace: a send refuses a member it has no skill directory for.
for rigMember in magic-coordinator keeper-myx ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
done
rigHost="$( hostname -s 2>/dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One accept, guarded to this rig's own trees, the fake curl first on PATH; output into <result>, rc into <result>.rc.
## RIG_ACCEPT_OP (default --magic-board-to-processed) by RIG_ACCEPT_WHO (default magic-coordinator),
## from a session acting as RIG_AGENT when set.
rigAccept(){ ## result file, item filename, from state
	: > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	env -i HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_SCENARIO="$rigTmp" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "${RIG_ACCEPT_OP:---magic-board-to-processed}" "${RIG_ACCEPT_WHO:-magic-coordinator}" "$2" --from-state:"$3" > "$1" 2>&1
	printf '%s' "$?" > "$1.rc"
}
rigItem(){ ## state, item filename, spawn-id or empty
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-succeeded\n%s---\n\n# rig dispatch\n' "${3:+spawn-id: $3
}" > "$rigData/board/$1/$2"
}
rigRecord(){ ## spawn-id, status, host, session-thread or empty
	mkdir -p "$rigSpawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n%sspawns: rig\n---\n' "$1" "$1" "$3" "$2" "${4:+session-thread: $4
}" > "$rigSpawned/$1/$1.md"
}
rigPosts(){ LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" ; }
rigAcceptLine(){ LC_ALL=C grep -m1 '^ACCEPT-DISMISS: ' "$1" | LC_ALL=C sed -E 's/^(ACCEPT-DISMISS: (sent DISMISSED|not sent)).*/\1/' ; }

echo "-- live child on this host: accept sends DISMISSED into its session thread --"
rigLiveSpawn="rig-live-$$-a1b2"
bash -c 'sleep 120 ; :' "$rigLiveSpawn" &
rigLivePid=$!
## Disowned, so its kill at exit is not reported as a job ending.
disown "$rigLivePid" 2>/dev/null || :
sleep 1
ps -A -ww -o args= | LC_ALL=C grep -q -F "$rigLiveSpawn" || rigRefuse "the stand-in child process is not visible in ps, so liveness would not be measured"
rigRecord "$rigLiveSpawn" spawn-started "$rigHost" CRIGSESS1:1700000000.000100
rigItem review dispatch-rig-live.md "$rigLiveSpawn"
rigAccept "$rigTmp/o1" dispatch-rig-live.md review
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o1.rc" )" 0
rigAssert "the item lands in board/processed"              "$( [ -f "$rigData/board/processed/dispatch-rig-live.md" ] && echo yes )" yes
rigAssert "the op reports the send"                        "$( rigAcceptLine "$rigTmp/o1" )" "ACCEPT-DISMISS: sent DISMISSED"
rigAssert "exactly one post reached Slack"                 "$( rigPosts )" 1
rigAssert "the post went to the session thread's channel"  "$( LC_ALL=C grep -c '"channel": *"CRIGSESS1"' "$rigTmp/bodies" )" 1
rigAssert "the post is a reply in the session thread"      "$( LC_ALL=C grep -c '"thread_ts": *"1700000000.000100"' "$rigTmp/bodies" )" 1
## The text as the child's Wait would render it (JSON \n as a real newline), judged by the
## one dismissal rule the Wait itself uses.
rigText="$( LC_ALL=C sed -n -E 's/^\{"channel":"[^"]*","text":"(([^"\\]|\\.)*)".*/\1/p' "$rigTmp/bodies" | head -1 )"
rigText="$( printf '%b' "$rigText" )"
rigAssert "the child's Wait reads the post as its dismissal" \
	"$( printf '1700000001.000200 | URIGBOT01 | %s\n' "$rigText" | LC_ALL=C awk -v agent=keeper-myx -f "$rigLib/AgentsDismissalMatch.awk" -f "$rigLib/AgentsHarnessWaitDismissed.awk" > /dev/null && echo dismissed )" dismissed
rigAssert "it dismisses no other member"                   \
	"$( printf '1700000001.000200 | URIGBOT01 | %s\n' "$rigText" | LC_ALL=C awk -v agent=magic-tester -f "$rigLib/AgentsDismissalMatch.awk" -f "$rigLib/AgentsHarnessWaitDismissed.awk" > /dev/null && echo dismissed )" ""

echo "-- child on another host: liveness unmeasurable here, so the dismissal is sent --"
rigRecord rig-foreign-c3d4 spawn-started rig-other-host CRIGSESS2:1700000000.000300
rigItem review dispatch-rig-foreign.md rig-foreign-c3d4
rigAccept "$rigTmp/o2" dispatch-rig-foreign.md review
rigAssert "the move succeeds"                              "$( cat "$rigTmp/o2.rc" )" 0
rigAssert "the op reports the send"                        "$( rigAcceptLine "$rigTmp/o2" )" "ACCEPT-DISMISS: sent DISMISSED"

echo "-- nothing to send: the move still succeeds and says why --"
rigRecord rig-ended-e5f6 spawn-succeeded "$rigHost" CRIGSESS3:1700000000.000400
rigItem review dispatch-rig-ended.md rig-ended-e5f6
rigAccept "$rigTmp/o3" dispatch-rig-ended.md review
rigAssert "ended child: the move succeeds"                 "$( cat "$rigTmp/o3.rc" )" 0
rigAssert "ended child: the item lands in processed"       "$( [ -f "$rigData/board/processed/dispatch-rig-ended.md" ] && echo yes )" yes
rigAssert "ended child: nothing posted"                    "$( rigPosts )" 0
rigAssert "ended child: the op says it has ended"          "$( LC_ALL=C grep -c '^ACCEPT-DISMISS: not sent: spawn rig-ended-e5f6 has already ended' "$rigTmp/o3" )" 1

rigRecord rig-gone-a7b8 spawn-started "$rigHost" CRIGSESS4:1700000000.000500
rigItem review dispatch-rig-gone.md rig-gone-a7b8
rigAccept "$rigTmp/o4" dispatch-rig-gone.md review
rigAssert "process gone: the move succeeds"                "$( cat "$rigTmp/o4.rc" )" 0
rigAssert "process gone: nothing posted"                   "$( rigPosts )" 0
rigAssert "process gone: the op says it is not running"    "$( LC_ALL=C grep -c '^ACCEPT-DISMISS: not sent: spawn rig-gone-a7b8 is not running on this host' "$rigTmp/o4" )" 1

rigRecord rig-nothread-c9d0 spawn-started rig-other-host ""
rigItem review dispatch-rig-nothread.md rig-nothread-c9d0
rigAccept "$rigTmp/o5" dispatch-rig-nothread.md review
rigAssert "no thread: the move succeeds"                   "$( cat "$rigTmp/o5.rc" )" 0
rigAssert "no thread: nothing posted"                      "$( rigPosts )" 0
rigAssert "no thread: the op says there is no thread"      "$( LC_ALL=C grep -c '^ACCEPT-DISMISS: not sent: spawn rig-nothread-c9d0 has no session thread' "$rigTmp/o5" )" 1

rigItem review dispatch-rig-unlinked.md ""
rigAccept "$rigTmp/o6" dispatch-rig-unlinked.md review
rigAssert "no spawn: the move succeeds"                    "$( cat "$rigTmp/o6.rc" )" 0
rigAssert "no spawn: the op says no record was found"      "$( LC_ALL=C grep -c '^ACCEPT-DISMISS: not sent: no spawn record found' "$rigTmp/o6" )" 1

echo "-- a same-state edit of a processed item is not an accept --"
rigAccept "$rigTmp/o7" dispatch-rig-live.md processed
rigAssert "the edit succeeds"                              "$( cat "$rigTmp/o7.rc" )" 0
rigAssert "no ACCEPT-DISMISS line, nothing posted"         "$( LC_ALL=C grep -c '^ACCEPT-DISMISS: ' "$rigTmp/o7" ):$( rigPosts )" 0:0

echo "-- who accepts: the coordinator's stub, or the review flow's own implementation --"
rigItem review dispatch-rig-who.md ""
RIG_AGENT=keeper-myx rigAccept "$rigTmp/o8" dispatch-rig-who.md review
rigAssert "the coordinator's stub from another member's session is refused, the item stays" "$( cat "$rigTmp/o8.rc" ):$( [ -f "$rigData/board/review/dispatch-rig-who.md" ] && echo stays ):$( LC_ALL=C grep -c "magic-board-to-processed is magic-coordinator's only" "$rigTmp/o8" )" 1:stays:1
RIG_AGENT=keeper-myx RIG_ACCEPT_OP=--intern-op-board-to-processed RIG_ACCEPT_WHO=keeper-myx rigAccept "$rigTmp/o9" dispatch-rig-who.md review
rigAssert "the review flow's implementation op accepts it for that member's own review" "$( cat "$rigTmp/o9.rc" ):$( [ -f "$rigData/board/processed/dispatch-rig-who.md" ] && echo processed )" 0:processed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD ACCEPT DISMISS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_ACCEPT_DISMISS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
