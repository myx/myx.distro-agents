#!/usr/bin/env bash
## Behavioural check on S6.6 of `20261102-refactorings.epic.md`: "Every MCP server instance, a root
## harness included, uses its workspace's `.local/agents` and `.local/temp` as its scratch root, even
## on a workspace that is not a rig. Its sessions are recorded and shown in the console. A root that
## spawns into other workspaces keeps its own session in its own workspace."
##
## Held, run rather than read: ONE REAL SERVER per case, given its own stdin and answering its own
## tools/call requests. The workspace is a plain one -- `.local/agents` and `.local/temp`, no rig
## marker, no spawn of its own -- and nothing stands in for the server.
##   1. the server carries a scratch root in that workspace, named in its own start, and `mint`
##      answers a session id, the token that proves it, and the instruction, as no error;
##   2. the minted session is recorded in the workspace it was minted in: its folder under
##      `.local/agents/sessions` holding the token, and the server's own store
##      `<workspace>/.local/temp/agent-mcp.<pid>/root-session` holding the id and the token;
##   3. the session's run is recorded for the console: a spawn record of that id under
##      `.local/agents/spawned`, marked `start-context: root-harness` and started, naming the
##      server's own process as its run;
##   4. `info` returns the id the server carries, and a SECOND server in another workspace adopts
##      that id with the token mint printed and carries it in turn.
##
## WHY IT IS RED ON THE TREE BEFORE THE FIX: `AgentsToolsRootSessionServe` takes four arguments
## (server pid, operation, id, token), and its one caller passes five, the scratch root first
## (`AgentsTools.InternMcpRequest.include:689`). The scratch root is read as the server's pid, the
## store path is built from a folder that is not there, and every operation answers "this server has
## no scratch root" -- mint, adopt and info alike.
##
## Offline: no socket is opened. A fake curl stands first on PATH, so a server that reached the
## network would be caught here; every workspace is a folder of this rig's own. The tree under test
## is whatever MDLT_ORIGIN names, so a red run needs the planted tree named there.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"

rigOriginIn="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOriginIn/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigPackage/sh-lib/harness/AgentsHarnessJsonField.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigField" "$rigPackage/sh-lib/mcp/AgentsTools.InternMcpRequest.include" "$rigPackage/sh-lib/mcp/AgentsTools.RootSession.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootSessionScratchRootCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## THE RIG ORIGIN: a COPY of the tree under test, and a stand-in for each sibling the server's start
## reads and that origin does not carry. The server, its tools and every file it writes are the
## package's own.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents" "$rigOrigin/myx/myx.distro-system/sh-lib" \
	"$rigOrigin/myx/myx.distro-.local/sh-lib" "$rigOrigin/myx/myx.distro-agents/sh-test" "$rigTmp/bin" "$rigTmp/home"
for rigPart in sh-lib sh-scripts project.inf ; do
	[ ! -e "$rigPackage/$rigPart" ] || cp -Rp "$rigPackage/$rigPart" "$rigOrigin/myx/myx.distro-agents/" \
		|| rigRefuse "cannot copy $rigPart into the rig origin"
done
printf '%s\n' '#!/usr/bin/env bash' \
	'## Rig stand-in for the system context: this origin may carry myx.distro-agents alone.' \
	'DistroSystemContext(){ return 0 ; }' \
	'Distro(){ return 1 ; }' \
	'Require(){ return 1 ; }' \
	'Action(){ return 0 ; }' \
	> "$rigOrigin/myx/myx.distro-system/sh-lib/SystemContext.include"
printf '%s\n' '#!/usr/bin/env bash' \
	'## Rig stand-in for the settings reader: this rig has no settings, so every read finds none.' \
	'return 0' \
	> "$rigOrigin/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
printf '%s\n' '#!/bin/sh' \
	'printf "rig-curl-called %s\n" "$*" >> "${RIG_CURL_LOG:-/dev/null}"' \
	'printf "{\"ok\":false,\"error\":\"rig_no_network\"}\n"' \
	> "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

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
rigYesNo(){ ## value -- yes when non-empty
	[ -n "$1" ] && printf yes || printf no
}
rigFileYes(){ ## path -- yes when it is a non-empty file
	[ -s "$1" ] && printf yes || printf no
}
rigDirYes(){ ## path -- yes when it is a folder
	[ -d "$1" ] && printf yes || printf no
}
rigPathless(){ ## text -- yes when it carries no slash
	printf '%s\n' "$1" | LC_ALL=C grep -q / && printf no || printf yes
}
rigBare(){ ## value -- yes when it is a bare name this package takes as a session
	case "$1" in
		''|.|..|*/*|*[[:space:]]*) printf no ;;
		*) printf yes ;;
	esac
}
rigAnswered(){ ## answer line file -- yes when the server answered that request
	[ -s "$1" ] && printf yes || printf no
}
rigValue(){ ## wire line file, json path -- decoded scalar, empty when absent
	LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigField" < "$1" 2> /dev/null || :
}
rigText(){ ## answer line file -- the first text part of the result
	rigValue "$1" result.content.0.text
}
rigIsError(){ ## answer line file -- yes when the call was refused
	case "$( rigValue "$1" result.isError )" in
		true) printf yes ;;
		*)    [ -n "$( rigValue "$1" error.message )" ] && printf yes || printf no ;;
	esac
}
rigFieldOf(){ ## text, key -- the value of that result line, first one
	printf '%s\n' "$1" | LC_ALL=C sed -n "s/^$2: //p" | head -n 1
}
rigCall(){ ## id, operation, extra arguments JSON (empty for none) -- one tools/call request
	if [ -z "${3:-}" ] ; then
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s"}}}\n' "$1" "$2"
	else
		printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"RootSession","arguments":{"operation":"%s",%s}}}\n' "$1" "$2" "$3"
	fi
}
rigServerPid=""
rigServer(){ ## wire file, workspace, pid file -- one real server run over its stdin
	## Its pid goes to a file, never to a variable: on the right of a pipe this runs in a subshell,
	## and a variable set there would never reach the check.
	local srvWire="$1" srvWs="$2" srvPidFile="$3"
	: > "$srvPidFile"
	mkdir -p "$srvWs/.local/temp" || rigRefuse "cannot make the workspace $srvWs"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SANDBOX_ROOT \
		-u MDAT_SPAWN_LAUNCH_MARKER -u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u MDAT_TEAM_MEMBER \
		-u MDAT_WORKSPACE_MODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$srvWs" MDLT_ORIGIN="$rigOrigin" HOME="$rigTmp/home" RIG_CURL_LOG="$rigTmp/curl.log" \
		PATH="$rigTmp/bin:$PATH" \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-server --run \
		> "$srvWire" 2> "$srvWire.err" || :
	rigServerPid="$( LC_ALL=C sed -n 's/.*scratch=.*\/agent-mcp\.\([0-9][0-9]*\).*/\1/p' "$srvWire.err" | head -n 1 )"
	printf '%s\n' "$rigServerPid" > "$srvPidFile"
}
rigWaitAnswer(){ ## wire file, id, seconds -- waits until the wire holds that answer
	local waWire="$1" waId="$2" waLeft=$(( ${3:-60} * 5 ))
	while [ ! -s "$waWire" ] || ! LC_ALL=C grep -q "\"id\":$waId," "$waWire" 2> /dev/null ; do
		[ "$waLeft" -gt 0 ] || return 1
		sleep 0.2 ; waLeft=$(( waLeft - 1 ))
	done
	return 0
}
rigServerLive(){ ## wire file, workspace, pid file -- a server whose stdin is held open, so its store can be read while it lives
	local liveWire="$1" liveWs="$2" livePidFile="$3" liveFeed="$3.feed"
	mkdir -p "$liveWs/.local/temp" || rigRefuse "cannot make the workspace $liveWs"
	: > "$livePidFile" ; : > "$liveWire"
	rm -f "$liveFeed"
	mkfifo "$liveFeed" || rigRefuse "cannot make the feed of the live server"
	env -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SANDBOX_ROOT \
		-u MDAT_SPAWN_LAUNCH_MARKER -u MDAT_DATA_ROOT -u MDAT_MCP_SERVED_MARKER -u MDAT_TEAM_MEMBER \
		-u MDAT_WORKSPACE_MODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$liveWs" MDLT_ORIGIN="$rigOrigin" HOME="$rigTmp/home" RIG_CURL_LOG="$rigTmp/curl.log" \
		PATH="$rigTmp/bin:$PATH" \
		bash "$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-server --run \
		< "$liveFeed" > "$liveWire" 2> "$liveWire.err" &
	rigLiveSrvPid=$!
	## The fifo is opened by a writer held here: closing it is what ends the server.
	exec 9> "$liveFeed"
	## Its start line is written a moment after the process starts, so the pid is read in a loop until
	## it is there: a single read races the server's own first line.
	local liveLeft=300
	while [ ! -s "$livePidFile" ] && [ "$liveLeft" -gt 0 ] ; do
		LC_ALL=C sed -n 's/.*scratch=.*\/agent-mcp\.\([0-9][0-9]*\).*/\1/p' "$liveWire.err" 2> /dev/null | head -n 1 > "$livePidFile"
		[ -s "$livePidFile" ] || sleep 0.2
		liveLeft=$(( liveLeft - 1 ))
	done
}
rigServerLiveEnd(){ ## wire file, request id -- ask the held server for one answer, then close its stdin and wait for it
	local endWire="$1" endId="$2"
	rigWaitAnswer "$endWire" "$endId" 90 || :
	exec 9>&-
	wait "$rigLiveSrvPid" 2> /dev/null || :
}
rigReply(){ ## wire file, request id -- the line carrying that answer, empty when none
	local rpFile="$1.id$2"
	: > "$rpFile"
	LC_ALL=C grep "\"id\":$2," "$1" > "$rpFile" 2> /dev/null || :
	printf '%s' "$rpFile"
}

## ---- 1. a server in a plain workspace carries a scratch root, and mints a session ----
echo "-- 1. a plain workspace with .local/agents and .local/temp: the server mints a session --"
rustWs="$rigTmp/w1"
mkdir -p "$rustWs/.local/agents" "$rustWs/.local/temp"
## The server's stdin is held open, so its scratch root can be read while it lives: it removes that
## root as it ends (AgentsTools.InternMcpServer.include, its trap and the `rm -rf` after `wait`).
rigCall 2 mint > "$rigTmp/w1.in"
rigServerLive "$rigTmp/w1.wire" "$rustWs" "$rigTmp/w1.pid"
LC_ALL=C cat "$rigTmp/w1.in" >&9
rigServerPid="$( cat "$rigTmp/w1.pid" )"
rigAssert "the server's own start names its scratch root in this workspace" "$( rigYesNo "$rigServerPid" )" yes
rustId=""
rigWaitAnswer "$rigTmp/w1.wire" 2 90 || :
rustAnswer="$( rigReply "$rigTmp/w1.wire" 2 )"
rigAssert "the server answered the mint"                          "$( rigAnswered "$rustAnswer" )" yes
rustText="$( rigText "$rustAnswer" )"
rigAssert "the mint is not an error"                              "$( rigIsError "$rustAnswer" )" no
rustId="$( rigFieldOf "$rustText" SESSION )"
rustToken="$( rigFieldOf "$rustText" TOKEN )"
rigAssert "it returns a session id"                               "$( rigYesNo "$rustId" )" yes
rigAssert "the id is a bare name"                                 "$( rigBare "$rustId" )" yes
rigAssert "it returns the token that proves it"                   "$( rigYesNo "$rustToken" )" yes
rigAssert "it returns the instruction on where to use it"         "$( rigYesNo "$( rigFieldOf "$rustText" USE )" )" yes
rigAssert "no result carries a path-shaped value"                 "$( rigPathless "$rustText" )" yes

## ---- 2. the session is recorded in the workspace it was minted in, while the server lives ----
echo "-- 2. the minted session is recorded there, and the store is the server's own --"
rustStore="$rustWs/.local/temp/agent-mcp.$rigServerPid/root-session"
rigAssert "its folder is under that workspace's .local/agents/sessions" "$( rigDirYes "$rustWs/.local/agents/sessions/$rustId" )" yes
rigAssert "the token mint printed is kept there"                  "$( rigFileYes "$rustWs/.local/agents/sessions/$rustId/root-session.token" )" yes
rigAssert "the server keeps the session in its own store under .local/temp" "$( rigFileYes "$rustStore" )" yes
rigAssert "and that store holds the id and the token, on one line" \
	"$( [ -s "$rustStore" ] && LC_ALL=C awk -v want="$rustId" 'NF == 2 && $1 == want { held = 1 } END { print ( held ? "yes" : "no" ) }' "$rustStore" || : )" yes

## ---- 3. the run is recorded, so the console shows the session ----
echo "-- 3. the session's run is recorded for the console, with the server's process as its run --"
rustRecord="$rustWs/.local/agents/spawned/$rustId/$rustId.spawn.md"
rigAssert "a spawn record of that session is under .local/agents/spawned" "$( rigFileYes "$rustRecord" )" yes
rigAssert "it is marked a root harness session, and started"      \
	"$( [ -s "$rustRecord" ] && LC_ALL=C grep -c -x -e 'start-context: root-harness' -e 'status: spawn-started' "$rustRecord" | LC_ALL=C tr -d ' ' || : )" 2
## The mark that tells this record from a console run's: a console run's record names the run it started,
## a root-harness record names no console run at all. Read here so a later change to either is seen.
rigAssert "and it names no console run, which is what marks it a root harness record" \
	"$( [ -s "$rustRecord" ] && LC_ALL=C grep -c -x -e 'cli: claude-native' -e 'cli: claude' -e 'cli-setting:.*' "$rustRecord" | LC_ALL=C tr -d ' ' || : )" 0
rigAssert "and its run-process is the server's own pid"           \
	"$( [ -n "$rigServerPid" ] && [ -s "$rustRecord" ] && LC_ALL=C sed -n "s/^run-process: \\($rigServerPid\\) .*/\\1/p" "$rustRecord" || : )" "$rigServerPid"
rigServerLiveEnd "$rigTmp/w1.wire" 2
rigAssert "and the scratch root is gone once that server ended"    "$( [ -n "$rigServerPid" ] && [ ! -e "$rustWs/.local/temp/agent-mcp.$rigServerPid" ] && printf yes || printf no )" yes

## ---- 4. a second server adopts the minted session ----
echo "-- 4. a second server adopts the minted session with the token --"
## `adopt` alone, held open: a server serves each request in a process of its own, so an `info` sent
## beside an `adopt` can run before it and answer nothing. The store it writes while it lives is what
## says the adoption took, and `info` was read in the run that minted (section 1's server carries it).
rigServerLive "$rigTmp/w2.wire" "$rustWs" "$rigTmp/w2.pid"
printf '%s\n' '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{}}' >&9
rigCall 3 adopt "\"session\":\"$rustId\",\"token\":\"$rustToken\"" >&9
rigWaitAnswer "$rigTmp/w2.wire" 3 90 || :
rigAdopt="$( rigReply "$rigTmp/w2.wire" 3 )"
rigAdoptId="$( rigFieldOf "$( rigText "$rigAdopt" )" SESSION )"
rigStore2="$rustWs/.local/temp/agent-mcp.$( cat "$rigTmp/w2.pid" )/root-session"
rigServerLiveEnd "$rigTmp/w2.wire" 3
rigAssert "the second server answered the adopt"                  "$( rigAnswered "$rigAdopt" )" yes
rigAssert "the mint printed both an id and its token, so the adopt has something to carry" \
	"$( rigYesNo "$rustId" ):$( rigYesNo "$rustToken" )" yes:yes
rigAssert "a second server of the same workspace adopts the id with the token" "$( rigIsError "$rigAdopt" )" no
## One comparison, not two: an id read out of a refused answer is empty, and two empties agree.
rigAssert "the adopt answers with the id mint printed"            "$( rigYesNo "$rigAdoptId" ):$rigAdoptId" "yes:$rustId"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT SESSION SCRATCH ROOT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROOT_SESSION_SCRATCH_ROOT: OK (%d assertions, one real server per case, no socket)\n' "$rigPassCount"
