#!/usr/bin/env bash
## Behavioural check on S6.41: a reviewer reads what it reviews with no ask. Twice on the night of
## 4 November a spawned run sat over 25 minutes on a RequestPermission for a file read while the
## human-owner slept, so two seats join the floor and this check proves both:
##   A. every member reads an epic in a workspace's source tree, with no grant and no ask (S17.4's
##      "a member reads one with no ask");
##   B. a run reads the session record of a run it reviews: its own child's, and the peer's that its
##      dispatch item cites in `references:` -- the session chat, the log and results inside the
##      store, and the output/ folder the peer wrote (S13.6's material).
## Proved through the real served gate, the grant read, the holds check and the native client's
## hook, so one answer comes from all four.
##   1. the epic is read, and nothing beside it is;
##   2. a child's and a cited peer's session record are read, and a stranger's is not.
## Red recipe: on live, every read in sections 1 and 2 says "path not in the allowed access-root
## set", and the grant read and the hook name nothing.
## Offline: the workspace, the team data, HOME and every registry are this rig's own tree; a fake
## curl is first on PATH and opens no socket.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/harness/AgentsUniversalHarness.sh"
rigHook="$rigLib/client-hooks/allow-granted-native-tool.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigHook" "$rigFixture" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewReadGrantsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigData/board/running" "$rigData/board/processed" "$rigTmp/bin" "$rigSpawned" "$rigSessions" "$rigWs/.local/temp" "$rigWs/.local/.agents" \
	"$rigWs/.local/agents/members" "$rigWs/source/myx/todo-sketchpad/backlog" "$rigWs/source/myx/rig-proj" "$rigWs/ELSE"
: > "$rigWs/.local/agents/members.registry"
printf 'Name: rig-proj\n' > "$rigWs/source/myx/rig-proj/project.inf"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-architect magic-developer magic-librarian magic-tester ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
## The epic under review, a sketch beside it, and a file outside any source tree.
rigEpic="$rigWs/source/myx/todo-sketchpad/backlog/20261102-rig.epic.md"
rigSketch="$rigWs/source/myx/todo-sketchpad/backlog/20261102-rig.sketch.md"
printf '# 20261102 rig: the epic\n\nrig-epic-body\n' > "$rigEpic"
printf '# 20261102 rig: the sketch\n\nrig-seed sketch\n' > "$rigSketch"
printf 'rig-seed elsewhere\n' > "$rigWs/ELSE/e.txt"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One command in the rig, guarded to its own trees, the fake curl first on PATH. rigEnv carries
## the extra environment as NAME=value words. Output into <result>, rc into <result>.rc.
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"|"$RIG_TMP"/*) ;; *) exit 97 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call
	printf '%s' "$3" > "$rigTmp/tool.args"
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigTmp/tool.args"
}
rigItem(){ ## item stem, owner, front matter lines after the owner
	printf -- '---\nowner: %s\n%s\n---\n\n# rig item\n' "$2" "$3" > "$rigData/board/running/$1.md"
}
rigRunRecord(){ ## folder, run id, owner, parent spawn id, extra front matter line (may be empty)
	mkdir -p "$rigSpawned/$1/output" "$rigSessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nowner: %s\nstatus: spawn-started\n%s---\n\n# Spawn session\n' \
		"$2" "$2" "$4" "$3" "${5:+$5
}" > "$rigSpawned/$1/$2.spawn.md"
	printf 'rig-chat %s\n' "$2" > "$rigSessions/$2/session.chat"
	printf 'rig-report %s\n' "$2" > "$rigSpawned/$1/output/report.md"
}
## What the last served call came to: `refused` by a gate, else the word given when its output holds
## the text given.
rigCame(){ ## word, text
	case "$( cat "$rigTmp/call.out" )" in
		*'not in the allowed access-root set'*|*'not in the allowed write-root set'*) printf 'refused' ;;
		*'is a read-only place'*) printf 'readonly' ;;
		*"$2"*) printf '%s' "$1" ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigCall(){ ## member, session, tool, arguments JSON
	rigEnv=( MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" )
	rigTool "$rigTmp/call.out" "$3" "$4"
	rigEnv=()
}
rigRead(){ ## member, session, file, marker
	rigCall "$1" "$2" Read "{\"file_path\":\"$3\"}" ; rigCame read "$4"
}
rigEdit(){ ## member, session, file
	rigCall "$1" "$2" Edit "{\"file_path\":\"$3\",\"old_string\":\"rig-epic-body\",\"new_string\":\"rig-epic-body edited\"}" ; rigCame edited 'OK: replaced'
}
rigGrantRead(){ ## member, session, tool, path -- what grants that call, as its GRANT line says it
	rigEnv=( MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" )
	rigRun "$rigTmp/read.out" bash "$rigFn" --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	rigEnv=()
	LC_ALL=C sed -n 's/^GRANT: //p' "$rigTmp/read.out" | head -1
}
rigHolds(){ ## member, session, tool, path -- the HOLDS or NOT-HOLDS line
	rigEnv=( MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" )
	rigRun "$rigTmp/holds.out" bash "$rigFn" --intern-op-permission-holds "$1" "$3" "$4" --session-id "$2"
	rigEnv=()
	LC_ALL=C grep -E '^(HOLDS|NOT-HOLDS)' "$rigTmp/holds.out" | head -1
}
## The native client's PreToolUse hook asked about one call. It decides by the session index alone:
## `allow <what admitted it>`, `none` when no row does, else `deny`.
rigHookSays(){ ## member, session, tool, path
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"%s","pattern":"rig","old_string":"a","new_string":"b","content":"rig"}}' \
		"$2" "$rigWs" "$3" "$4" > "$rigTmp/hook.in"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" bash "$rigHook" < "$rigTmp/hook.in" 2> "$rigTmp/hook.err" \
	| case "$( cat )" in
		'') printf 'none' ;;
		*'"permissionDecision": "allow"'*) printf 'allow' ;;
		*) printf 'deny' ;;
	esac
}

## ---------------------------------------------------------------- the epic every member reads
echo "-- 1. an epic in a workspace's source tree is read with no grant --"
rigReview="dispatch-20261104T0000Z-review-peer"
rigPeerItem="dispatch-20261104T0000Z-peer"
rigStrangerItem="dispatch-20261104T0000Z-stranger"
rigRunRecord arch-folder rig-arch magic-architect none "spawns: $rigReview.md"
rigAssert "a read of the epic is admitted"                    "$( rigRead magic-architect rig-arch "$rigEpic" rig-epic-body )" read
rigAssert "by the floor, as the grant read says it"           "$( rigGrantRead magic-architect rig-arch Read "$rigEpic" )" "standing floor"
rigAssert "the holds check says the same"                     "$( rigHolds magic-architect rig-arch Read "$rigEpic" )" "HOLDS floor"
rigAssert "and the native client's index admits it too"       "$( rigHookSays magic-architect rig-arch Read "$rigEpic" )" allow
rigAssert "the seat is the epic file, not the tree it sits in" "$( rigRead magic-architect rig-arch "$rigSketch" rig-seed )" refused
rigAssert "nor does the seat grant any write"                 "$( rigEdit magic-architect rig-arch "$rigEpic" )" refused

## ---------------------------------------------------------------- the session record it reviews
echo "-- 2. a run reads the session record of the run it reviews --"
rigRunRecord child-folder rig-child magic-developer rig-arch
rigAssert "its child's session chat is read"                  "$( rigRead magic-architect rig-arch "$rigSessions/rig-child/session.chat" rig-chat )" read
rigAssert "by the floor, and the holds check agrees"          "$( rigGrantRead magic-architect rig-arch Read "$rigSessions/rig-child/session.chat" ):$( rigHolds magic-architect rig-arch Read "$rigSessions/rig-child/session.chat" )" "standing floor:HOLDS floor"
rigAssert "the output the child wrote is read"                "$( rigRead magic-architect rig-arch "$rigSpawned/child-folder/output/report.md" rig-report )" read
## A peer the dispatch cites: the review item names the peer's dispatch item in `references:`.
rigRunRecord peer-folder rig-peer magic-librarian none
rigRunRecord stranger-folder rig-stranger magic-librarian none
rigItem "$rigReview" magic-architect "status: dispatch-started"$'\n'"session-id: rig-arch"$'\n'"references: $rigPeerItem"
rigItem "$rigPeerItem" magic-librarian "status: dispatch-started"$'\n'"session-id: rig-peer"
rigItem "$rigStrangerItem" magic-librarian "status: dispatch-started"$'\n'"session-id: rig-stranger"
rigAssert "the cited peer's session chat is read"              "$( rigRead magic-architect rig-arch "$rigSessions/rig-peer/session.chat" rig-chat )" read
rigAssert "its output folder with it"                          "$( rigRead magic-architect rig-arch "$rigSpawned/peer-folder/output/report.md" rig-report )" read
rigAssert "and the native client's index admits the peer's chat too" "$( rigHookSays magic-architect rig-arch Read "$rigSessions/rig-peer/session.chat" )" allow
rigAssert "the control: a peer the dispatch does not cite is refused" "$( rigRead magic-architect rig-arch "$rigSessions/rig-stranger/session.chat" rig-chat )" refused
rigAssert "nor does the reviewer's seat reach another member's run"   "$( rigRead magic-tester rig-tester "$rigSessions/rig-peer/session.chat" rig-chat )" refused
rigAssert "nor a file elsewhere in the workspace"              "$( rigRead magic-architect rig-arch "$rigWs/ELSE/e.txt" rig-seed )" refused

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW READ GRANTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a reviewer cannot read the epic or the session record it was sent to review" >&2
	echo "  fix:  the floor rows of AgentsTools.Grants.include and AgentsToolsGrantsRunSeats" >&2
	exit 1
fi
printf 'REVIEW_READ_GRANTS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
