#!/usr/bin/env bash
## Behavioural check on the console's claude sign-in probe (claude-native). A stub
## `claude` answers `auth status` as signed in, signed out or with junk, and records
## whether it was started and with which key in its environment. The spawn proxy maps
## the console's rc 6 to SETUP_STATUS=cli-not-authenticated. Every run goes through one
## `env -i` whose child refuses to start outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsConsoleShellScript.template.sh"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTemplate" ] || rigRefuse "console template not found: $rigTemplate"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsConsoleClaudeSignInCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

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
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/bin" "$rigDir/home"
	printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$rigDir/ws/.local/MDLT.settings.env"
	printf 'SPAWN_CLI_SERVICE=claude-native\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	[ -z "$3" ] || printf 'ANTHROPIC_API_KEY=%s\n' "$3" >> "$rigDir/ws/.local/.agents/magic-team.agent.env"
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
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_TEMPLATE="$rigTemplate" \
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
rigAssert "and says so"                                 "$( rigHolds "$rigDir/err" 'claude is not signed in on this machine, so the configured ANTHROPIC_API_KEY is used for this spawn' )" yes

echo "-- signed out, no key, a spawn --"
rigScenario out-nokey out ""
rigConsole --cli claude-native --non-interactive RIG-PROMPT
rigAssert "it exits 6"                                  "$( cat "$rigDir/rc" )" 6
rigAssert "and never starts the CLI"                    "$( rigStarted )" 0

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
mkdir -p "$rigDir/data"
printf 'rig context' | env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
	bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
		case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
		cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy magic-tester --dispatch-doc:none --wait
	' > "$rigDir/out" 2> "$rigDir/err"
rigAssert "rc 6 is reported as cli-not-authenticated"   "$( LC_ALL=C grep -c '^SETUP_STATUS=cli-not-authenticated$' "$rigDir/out" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONSOLE CLAUDE SIGN-IN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_CLAUDE_SIGN_IN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
