#!/usr/bin/env bash
## A claude-native console generated from the template, run with a spawn sandbox root,
## hands claude --add-dir for the sandbox's input/ and output/ and prints no `command not
## found`. The console is generated here by --make-console-command into this rig's own
## workspace; RIG_CONSOLE may name another console file to judge instead, for a red run.
## Every run goes through one `env -i` whose child refuses to start outside the rig tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsConsoleSandboxAccessCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/sandbox/input" "$rigTmp/sandbox/output"
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigWs/.local/MDLT.settings.env"
printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The stub claude is signed in, and records the argv it was started with.
printf '#!/bin/sh\nif [ "$1" = auth ] ; then echo "{\\"loggedIn\\":true}" ; exit 0 ; fi\nfor a in "$@" ; do printf "%%s\\n" "$a" ; done > "%s/claude.argv"\n' "$rigTmp" > "$rigTmp/bin/claude"
chmod +x "$rigTmp/bin/claude"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigGuarded(){ ## command...
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/sandbox" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v claude )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: claude is not the rig stub" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec "$@"
		' rig "$@"
}

if [ -n "${RIG_CONSOLE:-}" ] ; then
	cp "$RIG_CONSOLE" "$rigWs/DistroAgentsConsole.sh" || rigRefuse "could not copy the console to judge: $RIG_CONSOLE"
	chmod +x "$rigWs/DistroAgentsConsole.sh"
else
	rigGuarded bash "$rigFn" --make-console-command --quiet > /dev/null 2> "$rigTmp/make.err"
fi
[ -x "$rigWs/DistroAgentsConsole.sh" ] || rigRefuse "no console was generated: $( tail -2 "$rigTmp/make.err" 2>/dev/null )"

echo "-- a claude-native spawn with a sandbox root --"
rigGuarded bash "$rigWs/DistroAgentsConsole.sh" --cli claude-native --non-interactive RIG-PROMPT < /dev/null > "$rigTmp/out" 2> "$rigTmp/err"
[ -f "$rigTmp/claude.argv" ] || rigRefuse "the console never started claude: $( tail -3 "$rigTmp/err" )"
rigAdded(){ ## directory
	LC_ALL=C awk -v wantDir="$1" 'previous == "--add-dir" && $0 == wantDir { found = 1 ; } { previous = $0 ; } END { print found ? "yes" : "no" ; }' "$rigTmp/claude.argv"
}
rigAssert "no command is missing"                      "$( LC_ALL=C grep -c 'command not found' "$rigTmp/err" || : )" 0
rigAssert "claude gets --add-dir for input/"           "$( rigAdded "$rigTmp/sandbox/input" )" yes
rigAssert "and for output/"                            "$( rigAdded "$rigTmp/sandbox/output" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONSOLE SANDBOX ACCESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_SANDBOX_ACCESS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
