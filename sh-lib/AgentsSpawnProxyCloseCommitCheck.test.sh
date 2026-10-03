#!/usr/bin/env bash
## The spawn proxy commits its audit output log at close, and leaves the team-data store
## clean, on every way a spawn ends: a failing child, an interrupt while waiting, and the
## async branch once its subshell finishes. A fake DistroAgentsConsole.sh stands in for
## the CLI; MDAT_DATA_ROOT is a temp git store this rig creates -- never the real data.
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
## The output log the proxy named, relative to the store, and whether git holds it committed.
rigLogCommitted(){ ## proxy stdout file
	local logPath
	logPath="$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$1" | head -1 )"
	[ -n "$logPath" ] || { printf 'no-output-file' ; return 0 ; }
	logPath="${logPath#"$rigStore"/}"
	case "$logPath" in audit/*/*.output.log) ;; *) printf "not-under-audit: $logPath" ; return 0 ;; esac
	[ -n "$( git -C "$rigStore" ls-files -- "$logPath" )" ] && printf committed || printf "not-committed: $logPath"
}
rigProxy(){ ## child behaviour, stdout file, extra proxy args...
	local proxyChild="$1" proxyOut="$2" ; shift 2
	printf 'rig context' | ( cd "$rigTmp/ws" && env -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID RIG_CHILD="$proxyChild" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigStore" \
		bash "$rigFn" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:create "$@" ) > "$proxyOut" 2> "$proxyOut.err"
}

echo "-- a failing child, waited on --"
rigProxy fail "$rigTmp/f" --wait
rigAssert "the proxy reports the failure"              "$( LC_ALL=C grep -c '^EXIT_CODE=3$' "$rigTmp/f" )" 1
rigAssert "its output log is committed"                "$( rigLogCommitted "$rigTmp/f" )" committed
rigAssert "and the store is clean"                     "$( rigClean )" clean

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
rigAssert "its output log is committed"                "$( rigLogCommitted "$rigTmp/t" )" committed
rigAssert "and the store is clean"                     "$( rigClean )" clean

echo "-- the async branch, once its subshell ends --"
rigProxy async "$rigTmp/a"
rigAssert "the proxy returns at once, started"         "$( LC_ALL=C grep -c '^STATUS=started$' "$rigTmp/a" )" 1
rigLeft=40
while [ "$( rigLogCommitted "$rigTmp/a" )" != committed ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
sleep 2
rigAssert "its output log is committed after the subshell ends" "$( rigLogCommitted "$rigTmp/a" )" committed
rigAssert "and the store is clean"                     "$( rigClean )" clean
rigAssert "the async branch's new pending-reply close call reports no error" "$( LC_ALL=C grep -c ':no_entry:' "$rigTmp/a.err" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PROXY CLOSE COMMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PROXY_CLOSE_COMMIT: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
