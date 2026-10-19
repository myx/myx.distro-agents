#!/usr/bin/env bash
## Behavioural check on the one signal the generated console sends (sh-lib/AgentsConsoleShellScript.template.sh,
## DagcRunClaudeStreaming): it starts the vendor CLI in the background, waits for it, and forwards a TERM or an INT
## that comes to the console to that CLI, by a trap that names the CLI's pid. The trap stays for as long as the
## script lives, and the script lives on once the CLI has been waited for: it then waits for its formatter. A pid
## that has been waited for is a number the system gives again, so a TERM that comes then must reach nobody.
## (How long that is depends on the shell: a bash that can wait for a process substitution stays until the
## formatter has read everything the CLI left; the bash 3.2 of a Mac cannot, and leaves at once. The rule is held
## for either.)
## Runs the console itself, whole, with a stub `claude` first on PATH and, through BASH_ENV, the rig's own `kill`
## and `wait` in the console's shell: every signal the console asks for is kept, and a TERM is given to the
## console at the very moment it waits for another process than its CLI. Held here:
##   - a TERM that comes while the CLI runs is forwarded to it, as before: the CLI ends, and the console ends
##     with the status of a CLI that was ended so;
##   - ONCE THE CLI HAS BEEN WAITED FOR, A TERM SIGNALS NOBODY: nothing is sent to the number the CLI had, and
##     the console ends with the CLI's own status, as before;
##   - a CLI that ends by itself, and no TERM: nothing is signalled.
## Red: with the trap as it was, `kill -TERM "$claudePid"` whatever had become of that process, the second point
## fails: the number of the CLI that had ended is signalled.
## Offline: one mktemp tree, the stub the only CLI, every run through one `env -i` whose child refuses to start
## outside it; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsConsoleShellScript.template.sh"
rigHelper="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "console template not found: $rigTemplate"
[ -f "$rigHelper" ] || rigRefuse "the rig's process helper is not at the origin this workspace resolves: $rigHelper"
. "$rigHelper" || rigRefuse "the rig's process helper could not be read: $rigHelper"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleStreamTrapCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStandIns=""
trap 'rigProcSignalWithChildren KILL $rigStandIns ; rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment

## THE RIG'S OWN kill AND wait, in the shell of the console under test and in no process it starts.
## kill: every call is kept. A probe is handed on as it came; a signal is handed on only while the CLI of the rig
## has not ended, so that one sent to the number of a CLI that has ended reaches nobody, whoever has it.
## wait: handed on as it came. With RIG_TERM_AT_FORMATTER, where the CLI of the rig has ended and the console
## waits for another process than that one, the CLI has been waited for: a TERM is given to the console at that
## moment, once.
cat > "$rigTmp/console.env" <<'RIGENV'
unset BASH_ENV
kill(){
	printf '%s\n' "$*" >> "$RIG_DIR/kill.log"
	case "${1:-}" in -0) builtin kill "$@" ; return $? ;; esac
	[ -e "$RIG_DIR/claude.ended" ] || builtin kill "$@"
}
wait(){
	if [ -n "${RIG_TERM_AT_FORMATTER:-}" ] && [ -e "$RIG_DIR/claude.ended" ] && [ ! -e "$RIG_DIR/term.given" ] && [ "${1:-}" != "$( cat "$RIG_DIR/claude.pid" 2> /dev/null )" ] ; then
		: > "$RIG_DIR/term.given"
		builtin kill -TERM "$$"
	fi
	builtin wait "$@"
}
RIGENV

## A fresh workspace, signed in, and the stub claude: it says which process it is, and ends at once (ends) or
## stays (stays), as the scenario says.
rigScenario(){ ## name
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/bin" "$rigDir/home"
	printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigDir/ws/.local/MDLT.settings.env"
	printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf '%s\n' '#!/bin/sh' \
		'if [ "$1" = auth ] ; then printf "%s\n" "{\"loggedIn\":true}" ; exit 0 ; fi' \
		'echo "$$" > "$RIG_DIR/claude.pid"' \
		'[ "$RIG_CLAUDE" != stays ] || exec sleep 300' \
		': > "$RIG_DIR/claude.ended"' \
		'exit 0' > "$rigDir/bin/claude"
	chmod +x "$rigDir/bin/claude"
}
## One console run, guarded, in the background: its pid in rigConsolePid, noted as it is now.
rigConsole(){ ## what the stub does (ends, stays), a TERM at the formatter or empty
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_TEMPLATE="$rigTemplate" \
		RIG_DIR="$rigDir" RIG_CLAUDE="$1" RIG_TERM_AT_FORMATTER="${2:-}" RIG_ENV="$rigTmp/console.env" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$( command -v claude )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: claude is not the rig stub" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && BASH_ENV="$RIG_ENV" exec bash "$RIG_TEMPLATE" --cli claude-native --non-interactive RIG-PROMPT
		' rig < /dev/null > "$rigDir/out" 2> "$rigDir/err" &
	rigConsolePid=$!
	rigProcNote "$rigConsolePid" ; rigStandIns="$rigStandIns $rigConsolePid"
}
rigWaitFile(){ ## file -- waits, twenty seconds at most, for it to be there
	local fileTurns=100
	while [ ! -e "$1" ] && [ "$fileTurns" -gt 0 ] ; do sleep 0.2 ; fileTurns=$(( fileTurns - 1 )) ; done
	[ -e "$1" ]
}
rigAsked(){ ## what the console asked for (-0, -TERM) -- how many times, for the pid of the stub
	LC_ALL=C grep -c -x -F -- "$1 $( cat "$rigDir/claude.pid" 2> /dev/null )" "$rigDir/kill.log" 2> /dev/null || :
}
rigSignals(){ ## -- how many signals the console asked for in all, probes apart
	LC_ALL=C grep -c -v -e '^-0 ' "$rigDir/kill.log" 2> /dev/null || :
}

echo "-- a TERM while the CLI runs is forwarded to it --"
rigScenario stays
rigConsole stays ""
rigWaitFile "$rigDir/claude.pid" || rigRefuse "the stub CLI did not start, so nothing below would be measured: $( head -3 "$rigDir/err" 2> /dev/null )"
rigStubPid="$( cat "$rigDir/claude.pid" )"
rigProcNote "$rigStubPid" ; rigStandIns="$rigStandIns $rigStubPid"
sleep 1
rigProcSignal TERM "$rigConsolePid"
wait "$rigConsolePid" ; rigRc=$?
rigAssert "the console forwards it to its CLI, once, and to nobody else; the CLI ends, and the console ends with the status of a CLI ended so" \
	"$( rigAsked -TERM ) $( rigSignals ) $( [ -z "$( rigProcStill "$rigStubPid" )" ] && echo cli-ended || echo cli-runs ) $rigRc" "1 1 cli-ended 143"

echo "-- once the CLI has been waited for, a TERM signals nobody --"
rigScenario ended
rigConsole ends at-formatter
wait "$rigConsolePid" ; rigRc=$?
rigAssert "control: the CLI ended by itself, the console waited for it and came to wait for its formatter, and the TERM was given to the console then" \
	"$( [ -e "$rigDir/claude.ended" ] && echo cli-ended ) $( [ "$( rigAsked -0 )" -ge 1 ] && echo probed ) $( [ -e "$rigDir/term.given" ] && echo term-given )" "cli-ended probed term-given"
rigAssert "nothing is sent to the number the CLI had, nor to anyone, and the console ends with the CLI's own status" "$( rigAsked -TERM ) $( rigSignals ) $rigRc" "0 0 0"

echo "-- a CLI that ends by itself, and no TERM --"
rigScenario quiet
rigConsole ends ""
wait "$rigConsolePid" ; rigRc=$?
rigAssert "nothing is signalled, and the console ends with the CLI's own status" "$( [ -e "$rigDir/claude.ended" ] && echo cli-ended ) $( rigSignals ) $rigRc" "cli-ended 0 0"

echo "-- the trap names its CLI only while that is the script's to wait for --"
rigAssert "the trap of the template signals nothing where the pid is empty, and the pid is emptied once the CLI has been waited for" \
	"$( rigCode "$rigTemplate" | LC_ALL=C grep -c -F "trap '[ -n \"\$claudePid\" ] && kill -TERM \"\$claudePid\" 2>/dev/null' TERM INT" ) $( rigCode "$rigTemplate" | LC_ALL=C grep -c -x -e '[[:space:]]*claudePid=""' )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONSOLE STREAM TRAP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_STREAM_TRAP: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
