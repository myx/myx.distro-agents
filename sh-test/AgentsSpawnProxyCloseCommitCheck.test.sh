#!/usr/bin/env bash
## The spawn proxy keeps the child's output as the session's own log,
## .local/agents/sessions/<spawn-id>/session.log, never in the team data, and leaves the
## team-data store clean (its transcript committed) on every way a spawn ends: a failing
## child, an interrupt while waiting, and the async branch once its subshell finishes.
## A fake DistroAgentsConsole.sh stands in for
## the CLI; MDAT_DATA_ROOT is a temp git store this rig creates -- never the real data.
## Also covers board-review: a created dispatch item's close destination, a reused item's
## no-move, and the review-by header's two forms (bare session-id, or absent).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigFn="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsSpawnProxyCloseCommitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigStore="$rigTmp/store"
mkdir -p "$rigTmp/ws/.local/.agents" "$rigStore"
git -C "$rigStore" init -q || rigRefuse "could not init the temp store"
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the temp store"
## The fake console carries the vintage strings the proxy greps for, then does what RIG_CHILD says.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho rig-child-output\ncase "$RIG_CHILD" in fail) exit 3 ;; sleep) sleep 30 ;; async) sleep 2 ;; esac\nexit 0\n' > "$rigTmp/ws/DistroAgentsConsole.sh"
chmod +x "$rigTmp/ws/DistroAgentsConsole.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigClean(){
	[ -z "$( git -C "$rigStore" status --porcelain --untracked-files=all )" ] && printf clean || printf "dirty: $( git -C "$rigStore" status --porcelain --untracked-files=all | tr '\n' ' ' )"
}
## The session log the proxy named: the session's own, holding the child's output.
rigSessionLog(){ ## proxy stdout file
	local logPath
	logPath="$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$1" | head -1 )"
	[ -n "$logPath" ] || { printf 'no-output-file' ; return 0 ; }
	case "$logPath" in "$rigTmp/ws/.local/agents/sessions/"*/session.log) ;; *) printf "not-a-session-log: $logPath" ; return 0 ;; esac
	[ -f "$logPath" ] || { printf "absent: $logPath" ; return 0 ; }
	LC_ALL=C grep -q '^rig-child-output$' "$logPath" && printf session-log || printf "no-child-output: $logPath"
}
## Spawn output, a session log or a launch marker anywhere in the team data store: none belongs there.
rigOutputInStore(){
	find "$rigStore" -path "$rigStore/.git" -prune -o \( -name '*.output.log' -o -name 'session.log' -o -name '*.launch' \) -print | LC_ALL=C grep -c .
}
## Waits, up to 40 seconds, while a file lacks a line or a process is alive.
rigWaitLine(){ ## file, line pattern
	local waitLeft=40
	while ! LC_ALL=C grep -q "$2" "$1" 2>/dev/null && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}
rigWaitGone(){ ## pid
	local waitLeft=40
	while [ -n "$1" ] && kill -0 "$1" 2>/dev/null && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}
## The dispatch item's own name, as the proxy reported it on --dispatch-doc:create.
rigDispatchItem(){ ## proxy stdout file
	LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' "$1" | head -1
}
## Which board/<state>/ folder, if any, actually holds a named item right now.
rigItemBoardState(){ ## item filename
	local stateDir
	for stateDir in "$rigStore"/board/*/ ; do
		[ -f "$stateDir$1" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigProxy(){ ## child behaviour, stdout file, extra proxy args...
	local proxyChild="$1" proxyOut="$2" ; shift 2
	## RIG_PARENT_SESSION, unset/empty by default, feeds MDAT_SPAWN_SESSION_ID below --
	## empty and unset read the same to the proxy's own "${VAR:-...}" default. Both it
	## and CLAUDE_CODE_SESSION_ID are covered: an ambient one must never leak into a rig
	## meant to control parentSessionId itself (the review-by cases further down do).
	printf 'rig context' | ( cd "$rigTmp/ws" && env -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SESSION_ID RIG_CHILD="$proxyChild" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigStore" \
		MDAT_SPAWN_SESSION_ID="${RIG_PARENT_SESSION:-}" \
		bash "$rigFn" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:create "$@" ) > "$proxyOut" 2> "$proxyOut.err"
}
## Same shape, --dispatch-doc:reuse against an item already sitting in some board state.
rigProxyReuse(){ ## stdout file, item filename, extra proxy args...
	local proxyOut="$1" proxyItem="$2" ; shift 2
	printf 'rig context' | ( cd "$rigTmp/ws" && env -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigStore" \
		bash "$rigFn" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:reuse --from-board "$proxyItem" "$@" ) > "$proxyOut" 2> "$proxyOut.err"
}

echo "-- a failing child, waited on --"
rigProxy fail "$rigTmp/f" --wait
rigAssert "the proxy reports the failure"              "$( LC_ALL=C grep -c '^EXIT_CODE=3$' "$rigTmp/f" )" 1
rigAssert "its output lands in the session's own log"  "$( rigSessionLog "$rigTmp/f" )" session-log
rigAssert "and none of it in the team data"            "$( rigOutputInStore )" 0
rigAssert "and the store is clean"                     "$( rigClean )" clean
rigAssert "a created dispatch item closes into board/review" \
	"$( rigItemBoardState "$( rigDispatchItem "$rigTmp/f" )" )" review

echo "-- a reused tracking item: the close never moves it --"
mkdir -p "$rigStore/board/blocked"
printf -- '---\ntype: task\nowner: rig\n---\n\nreuse me\n' > "$rigStore/board/blocked/task-rig-reuse.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "seed reused item"
rigProxyReuse "$rigTmp/r" task-rig-reuse.md --wait
rigAssert "the reuse close reports no error"           "$( LC_ALL=C grep -c '^TRACKING_ITEM=task-rig-reuse\.md$' "$rigTmp/r" )" 1
rigAssert "the reused item stays in its own state"      "$( rigItemBoardState task-rig-reuse.md )" blocked
rigAssert "and the store is clean"                     "$( rigClean )" clean

echo "-- review-by: bare session-id when the parent session is set --"
RIG_PARENT_SESSION="rig-parent-session-uuid-1234" rigProxy fail "$rigTmp/pb" --wait
rigAssert "review-by carries the parent session id"    "$( LC_ALL=C grep -c -x -F 'review-by: rig-parent-session-uuid-1234' "$rigStore/board/review/$( rigDispatchItem "$rigTmp/pb" )" )" 1

echo "-- review-by: absent when the parent session is empty --"
unset RIG_PARENT_SESSION
rigProxy fail "$rigTmp/pe" --wait
rigAssert "no review-by header is written"             "$( LC_ALL=C grep -c '^review-by:' "$rigStore/board/review/$( rigDispatchItem "$rigTmp/pe" )" )" 0

echo "-- an interrupt while waiting --"
set -m
rigProxy sleep "$rigTmp/t" --wait &
rigProxyPid=$!
set +m
sleep 4
kill -TERM -- "-$rigProxyPid" 2>/dev/null
rigLeft=20
while kill -0 "$rigProxyPid" 2>/dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
kill -0 "$rigProxyPid" 2>/dev/null && { kill -KILL -- "-$rigProxyPid" 2>/dev/null ; rigRefuse "the proxy did not end after TERM, so its close could not be observed" ; }
{ wait "$rigProxyPid" ; } 2>/dev/null
## The TERM ends this job's own subshell at once, while the proxy under it runs its close
## on (transcript end, tokens, commits): wait for that close, which names its log last.
rigWaitLine "$rigTmp/t" '^OUTPUT_FILE='
sleep 2
rigAssert "its output lands in the session's own log"  "$( rigSessionLog "$rigTmp/t" )" session-log
rigAssert "and none of it in the team data"            "$( rigOutputInStore )" 0
rigAssert "and the store is clean"                     "$( rigClean )" clean

echo "-- the async branch, once its subshell ends --"
rigProxy async "$rigTmp/a"
rigAssert "the proxy returns at once, started"         "$( LC_ALL=C grep -c '^STATUS=started$' "$rigTmp/a" )" 1
rigWaitGone "$( LC_ALL=C sed -n 's/^PID=//p' "$rigTmp/a" | head -1 )"
sleep 1
rigAssert "its output lands in the session's own log, the subshell's close lines with it" \
	"$( rigSessionLog "$rigTmp/a" ):$( LC_ALL=C grep -c 'AI service used' "$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$rigTmp/a" | head -1 )" )" session-log:1
rigAssert "and none of it in the team data"            "$( rigOutputInStore )" 0
rigAssert "and the store is clean"                     "$( rigClean )" clean
rigAssert "no launch marker is left in any session's state" "$( find "$rigTmp/ws/.local/agents/sessions" -name 'launch*' | LC_ALL=C grep -c . )" 0
rigAssert "the async branch's new pending-reply close call reports no error" "$( LC_ALL=C grep -c ':no_entry:' "$rigTmp/a.err" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PROXY CLOSE COMMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PROXY_CLOSE_COMMIT: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
