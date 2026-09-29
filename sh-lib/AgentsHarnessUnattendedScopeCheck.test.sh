#!/usr/bin/env bash
## Behavioural check on which launches the harness gates as UNATTENDED. The gate itself
## is exercised under both markers by WriteSplit and PermissionCheck; this asks whether
## the launch paths a board task takes actually set them: a console run with
## --non-interactive, the spawn proxy the heartbeat and the Agent tool both use, and the
## Agent tool itself. The interactive console is the control that must stay attended.
## Offline: fake claude, fake console and fake curl, all under this rig's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/AgentsConsoleShellScript.template.sh" ] || rigRefuse "console template not found: $rigHere/AgentsConsoleShellScript.template.sh"
[ -x "$rigTools" ] || rigRefuse "team tooling not found: $rigTools"

rigTmp="$( mktemp -d -t AgentsHarnessUnattendedScopeCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/ws/.local"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigTmp/ws/.local/MDLT.settings.env"
## Every request is logged and refused; the closing assertion reads the log.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.log"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
## The console's sign-in probe (`claude auth status`) answers signed in and is not a start.
printf '#!/bin/sh\nif [ "$1" = auth ] ; then echo "{\\"loggedIn\\":true}" ; exit 0 ; fi\nprintf "unattended=[%%s] spawn=[%%s]\\n" "${MDAT_SESSION_UNATTENDED:-}" "${MDAT_SPAWN_SESSION_ID:-}" >> "%s/claude.log"\n' "$rigTmp" > "$rigTmp/bin/claude"
## The fake console carries the vintage strings the proxy greps for: cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\nprintf "args=[%%s] spawn=[%%s]\\n" "$*" "${MDAT_SPAWN_SESSION_ID:-}" >> "%s/console.log"\ncat > /dev/null\n' "$rigTmp" > "$rigTmp/ws/DistroAgentsConsole.sh"
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/claude" "$rigTmp/ws/DistroAgentsConsole.sh"
: > "$rigTmp/curl.log"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## Runs "$@" in its own process group with the rig's env cleared of both markers; a
## run still going after 60s has its whole group killed and reads as a hang.
rigRun(){ ## output file, command...
	local runOut="$1" runPid runRc=0 watchPid ; shift
	set -m
	env -u MDAT_SESSION_UNATTENDED -u MDAT_SPAWN_SESSION_ID -u MDAT_DATA_ROOT -u CLAUDE_CODE_ENTRYPOINT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" "$@" > "$runOut" 2>&1 &
	runPid=$!
	( sleep 60 ; kill -KILL -- "-$runPid" ) 2>/dev/null &
	watchPid=$!
	set +m
	wait "$runPid" || runRc=$?
	{ kill "$watchPid" ; wait "$watchPid" ; } 2>/dev/null
	return "$runRc"
}

echo "-- a console run with --non-interactive marks its CLI unattended --"
: > "$rigTmp/claude.log"
rigRun "$rigTmp/c1.out" bash "$rigHere/AgentsConsoleShellScript.template.sh" --cli claude-native --non-interactive RIG-PROMPT < /dev/null
rigAssert "the CLI started"                            "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/claude.log" )" 1
rigAssert "and saw the unattended marker"              "$( sed -n 's/^unattended=\[\([^]]*\)\].*/\1/p' "$rigTmp/claude.log" )" true
: > "$rigTmp/claude.log"
rigRun "$rigTmp/c2.out" bash "$rigHere/AgentsConsoleShellScript.template.sh" --cli claude-native < /dev/null
rigAssert "control: an interactive console's CLI started" "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/claude.log" )" 1
rigAssert "and saw no unattended marker"               "$( sed -n 's/^unattended=\[\([^]]*\)\].*/\1/p' "$rigTmp/claude.log" )" ""

echo "-- the spawn proxy starts the console non-interactively under a fresh session id --"
: > "$rigTmp/console.log"
printf 'rig context' > "$rigTmp/ctx"
rigRun "$rigTmp/p.out" env MDAT_SPAWN_SESSION_ID=rig-parent "$rigTools" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:none < "$rigTmp/ctx"
sleep 2
rigAssert "the proxy reports the spawn started, its session notice notwithstanding" "$( LC_ALL=C grep -c '^STATUS=started$' "$rigTmp/p.out" )" 1
rigAssert "the console got --non-interactive"          "$( LC_ALL=C grep -c -- '--non-interactive' "$rigTmp/console.log" )" 1
rigSpawnId="$( sed -n 's/.*spawn=\[\([^]]*\)\].*/\1/p' "$rigTmp/console.log" )"
rigAssert "under a session id of its own"              "$( [ -n "$rigSpawnId" ] && [ "$rigSpawnId" != rig-parent ] && printf fresh || printf "not fresh: [$rigSpawnId]" )" fresh

echo "-- the Agent tool spawns through the same proxy --"
: > "$rigTmp/console.log"
rigRun "$rigTmp/a.out" env MDAT_SPAWN_AGENT=magic-tester HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig \
	bash "$rigHere/AgentsUniversalHarness.sh" --intern-tool Agent < <( printf '{"agent":"magic-tester","prompt":"rig context"}' )
sleep 2
rigAssert "a nested spawn reaches the console non-interactively" "$( LC_ALL=C grep -c -- '--non-interactive' "$rigTmp/console.log" )" 1
rigAssert "under a session id of its own"              "$( [ -n "$( sed -n 's/.*spawn=\[\([^]]*\)\].*/\1/p' "$rigTmp/console.log" )" ] && printf fresh || printf missing )" fresh

echo "-- the heartbeat spawns through that proxy (call site only: PARTIAL) --"
## Text matching proves the call site exists and nothing more; the edited copy is its control.
rigHeartbeat="$rigHere/AgentsTools.MagicHeartbeat.include"
rigAssert "the heartbeat calls the spawn proxy"        "$( LC_ALL=C grep -c -- '--intern-op-agent-spawn-proxy' "$rigHeartbeat" )" 1
sed 's/--intern-op-agent-spawn-proxy/--rig-removed/' "$rigHeartbeat" > "$rigTmp/heartbeat.edited"
rigAssert "control: the same check on a copy without the call finds none" "$( LC_ALL=C grep -c -- '--intern-op-agent-spawn-proxy' "$rigTmp/heartbeat.edited" )" 0

echo "-- a served call is attended only from a known interactive client entrypoint --"
## A store write is the probe: attended calls may make it, unattended ones never do.
mkdir -p "$rigTmp/ws/.local/agents/sessions/rig"
rigStoreWrite(){ ## entrypoint or empty, unattended marker or empty, spawn id or empty, result file
	rm -f "$rigTmp/ws/.local/agents/sessions/rig/probe"
	rigRun "$4" env -u CLAUDE_CODE_ENTRYPOINT ${1:+CLAUDE_CODE_ENTRYPOINT="$1"} ${2:+MDAT_SESSION_UNATTENDED="$2"} ${3:+MDAT_SPAWN_SESSION_ID="$3"} \
		HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig bash "$rigHere/AgentsUniversalHarness.sh" --intern-tool Write \
		--access-read-root "$rigTmp/ws/.local/agents/sessions" --access-write-root "$rigTmp/ws/.local/agents/sessions" \
		< <( printf '{"path":"%s","content":"rig\\n"}' "$rigTmp/ws/.local/agents/sessions/rig/probe" )
}
## Read apart from the call: a call made inside $( ) loses job control, and with it its stdin.
rigGated(){ ## result file
	LC_ALL=C grep -q '^ERROR: path is in a team store' "$1" && printf unattended && return 0
	LC_ALL=C grep -q '^OK: wrote' "$1" && printf attended && return 0
	printf 'neither: %s' "$( LC_ALL=C grep -m1 '^ERROR' "$1" )"
}
rigStoreWrite "" "" "" "$rigTmp/m1.out"
rigAssert "no entrypoint and no marker is unattended"  "$( rigGated "$rigTmp/m1.out" )" unattended
rigStoreWrite sdk-cli "" "" "$rigTmp/m2.out"
rigAssert "sdk-cli (claude -p) is unattended"          "$( rigGated "$rigTmp/m2.out" )" unattended
rigStoreWrite rig-unknown "" "" "$rigTmp/m3.out"
rigAssert "an unknown entrypoint is unattended"        "$( rigGated "$rigTmp/m3.out" )" unattended
rigStoreWrite cli "" "" "$rigTmp/m4.out"
rigAssert "control: cli is attended"                   "$( rigGated "$rigTmp/m4.out" )" attended
rigStoreWrite claude-vscode "" "" "$rigTmp/m5.out"
rigAssert "control: claude-vscode is attended"         "$( rigGated "$rigTmp/m5.out" )" attended
rigStoreWrite cli true "" "$rigTmp/m6.out"
rigAssert "cli with the unattended marker is unattended" "$( rigGated "$rigTmp/m6.out" )" unattended
rigStoreWrite cli "" rig-spawn "$rigTmp/m7.out"
rigAssert "cli with a spawn id is unattended"          "$( rigGated "$rigTmp/m7.out" )" unattended

echo "-- offline --"
## The proxy's session notice stops at channel resolution, before any request is made.
rigAssert "the session notice failed at channel resolution" "$( LC_ALL=C grep -c 'could not resolve a channel' "$rigTmp/p.out" )" 1
rigAssert "no request left this box"                   "$( LC_ALL=C awk 'END { print NR ; }' "$rigTmp/curl.log" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ UNATTENDED SCOPE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_UNATTENDED_SCOPE: OK (%d assertions, offline; heartbeat by call site only)\n' "$rigPassCount"
