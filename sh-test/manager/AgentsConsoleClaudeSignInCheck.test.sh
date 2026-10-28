#!/usr/bin/env bash
## Behavioural check on the console's claude sign-in probe (claude-native). A stub
## `claude` answers `auth status` as signed in, signed out or with junk, and records
## whether it was started and with which key in its environment. The spawn proxy maps
## the console's rc 6 to SETUP_STATUS=cli-not-authenticated. A spawn nobody waits on
## answers ERROR, and no receipt of a start, when its console launched no CLI: the
## launch is what a start means, and it is waited for. Its control is the same spawn
## over a console that does launch one, which is the start it says it is.
## Every run goes through one `env -i` whose child refuses to start outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsConsoleShellScript.template.sh"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "console template not found: $rigTemplate"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleClaudeSignInCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A fresh workspace: settings naming the origin, an optional key, and the stub claude.
rigScenario(){ ## name, auth answer (in|out|junk), key value or empty
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/bin" "$rigDir/home" "$rigDir/data"
	printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigDir/ws/.local/MDLT.settings.env"
	printf 'SPAWN_TIER_NORMAL=claude-native\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env" ; printf 'PRESET_CLI_SERVICE=claude-native\n' > "$rigDir/ws/.local/.agents/preset-claude-native.agent.env"
	[ -z "$3" ] || printf 'ANTHROPIC_API_KEY=%s\n' "$3" >> "$rigDir/ws/.local/.agents/preset-claude-native.agent.env"
	case "$2" in
		in)   rigAnswer='{"loggedIn":true}' ;;
		out)  rigAnswer='{ "loggedIn": false }' ;;
		junk) rigAnswer='something unexpected' ;;
	esac
	printf '#!/bin/sh\nif [ "$1" = auth ] ; then printf "%%s\\n" %s ; exit 0 ; fi\nprintf "started key=[%%s]\\n" "${ANTHROPIC_API_KEY:-}" >> "%s/claude.log"\n' \
		"'$rigAnswer'" "$rigDir" > "$rigDir/bin/claude"
	chmod +x "$rigDir/bin/claude"
	: > "$rigDir/claude.log"
}
## One console run, guarded; rc into $rigDir/rc.
rigConsole(){ ## console args...
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_TEMPLATE="$rigTemplate" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$( command -v claude )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: claude is not the rig stub" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_TEMPLATE" "$@"
		' rig "$@" < /dev/null > "$rigDir/out" 2> "$rigDir/err"
	printf '%s' "$?" > "$rigDir/rc"
}
rigStarted(){ LC_ALL=C grep -c '^started ' "$rigDir/claude.log" || : ; }
rigKey(){ LC_ALL=C sed -n 's/^started key=\[\(.*\)\]$/\1/p' "$rigDir/claude.log" | head -1 ; }
rigHolds(){ ## file, text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
## One spawn-proxy call in the rig's workspace, guarded, the caller naming its own options: its stdout
## is $rigDir/out, its stderr $rigDir/err, its status $rigDir/rc.
rigSpawnProxy(){ ## proxy arguments...
	printf 'rig context' | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: data root outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:none "$@"
		' rig "$@" > "$rigDir/out" 2> "$rigDir/err"
	printf '%s' "$?" > "$rigDir/rc"
}

echo "-- signed in, a key configured --"
rigScenario in-key in rig-key-1
rigConsole --cli claude-native --non-interactive RIG-PROMPT
rigAssert "it starts"                                   "$( rigStarted )" 1
rigAssert "and does not export the key"                 "$( rigKey )" ""

echo "-- signed out, a key configured, a spawn --"
rigScenario out-key out rig-key-2
rigConsole --cli claude-native --non-interactive RIG-PROMPT
rigAssert "it starts"                                   "$( rigStarted )" 1
rigAssert "with the configured key exported"            "$( rigKey )" rig-key-2
rigAssert "and says so"                                 "$( rigHolds "$rigDir/err" 'claude reports itself not signed in, so the configured ANTHROPIC_API_KEY is used for this spawn' )" yes

echo "-- the probe reads signed out, no key, a spawn: the CLI is launched, and says what it says --"
rigScenario out-nokey out ""
rigConsole --cli claude-native --non-interactive RIG-PROMPT
rigAssert "it starts the CLI rather than refusing it"   "$( rigStarted )" 1
rigAssert "and ends on the CLI's own status"            "$( cat "$rigDir/rc" )" 0

echo "-- a junk answer --"
rigScenario junk junk ""
rigConsole --cli claude-native --non-interactive RIG-PROMPT
rigAssert "it starts, the probe having no verdict"      "$( rigStarted )" 1

echo "-- signed out, interactive --"
rigScenario out-interactive out ""
rigConsole --cli claude-native
rigAssert "it warns to sign in with /login"             "$( rigHolds "$rigDir/err" 'sign in with /login once it starts' )" yes
rigAssert "and starts"                                  "$( rigStarted )" 1

echo "-- the spawn proxy names rc 6 --"
rigScenario proxy in ""
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nexit 6\n' > "$rigDir/ws/DistroAgentsConsole.sh"
chmod +x "$rigDir/ws/DistroAgentsConsole.sh"
rigSpawnProxy --wait
rigAssert "rc 6 is reported as cli-not-authenticated"   "$( LC_ALL=C grep -c '^SETUP_STATUS=cli-not-authenticated$' "$rigDir/out" )" 1

echo "-- a spawn nobody waits on, whose console launches no CLI, is the error it is --"
rigScenario not-launched out ""
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nexit 6\n' > "$rigDir/ws/DistroAgentsConsole.sh"
chmod +x "$rigDir/ws/DistroAgentsConsole.sh"
rigSpawnProxy
rigAssert "no receipt calls it a start"                  "$( LC_ALL=C grep -c '^STATUS=' "$rigDir/out" )" 0
rigAssert "and it ends non-zero"                        "$( cat "$rigDir/rc" )" 1
rigAssert "saying that no CLI was launched"             "$( LC_ALL=C grep -c '⛔ ERROR: ' "$rigDir/err" ):$( rigHolds "$rigDir/err" 'no agent CLI was launched' )" "1:yes"

echo "-- and the control: the same spawn, whose console launches one, is the start it is --"
rigScenario launched out ""
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nprintf "rig-cli\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"\nexit 0\n' > "$rigDir/ws/DistroAgentsConsole.sh"
chmod +x "$rigDir/ws/DistroAgentsConsole.sh"
rigSpawnProxy
rigAssert "the receipt calls it a start"                 "$( LC_ALL=C grep -c '^STATUS=started$' "$rigDir/out" )" 1
rigAssert "and it ends well"                             "$( cat "$rigDir/rc" )" 0
## The run this receipt returned from closes behind it, in the rig's tree, before the trap removes that tree.
sleep 2

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONSOLE CLAUDE SIGN-IN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_CLAUDE_SIGN_IN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
