#!/usr/bin/env bash
## 2158 file modes. The installer writes the three MCP configs at 0644 even under umask
## 077, whether it creates them or finds one already at 0600, and ~/.claude.json at 0600;
## --owner-credential-store-self-test passes on those modes, fails naming a file at the
## wrong one, and states a file that is absent. Temp HOME and workspace only; every call
## goes through one `env -i` whose child refuses to run outside this rig's mktemp tree.
## The rig workspace carries no myx.distro-agents copy, so the installer ends rc 1 on its own
## distro-path check; the files it writes before that are what this rig reads.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLocalContext="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalContext.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigLocalContext" ] || rigRefuse "LocalContext.include not found: $rigLocalContext"
rigTmp="$( mktemp -d -t AgentsMcpFileModesCheck )" || exit 1
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
rigMode(){ ## path -- the permission string, or absent
	[ -e "$1" ] || { printf absent ; return 0 ; }
	ls -l "$1" | cut -c1-10
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigScenario(){ ## name -- a workspace that passes the set-up check, and an empty HOME
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/home" "$rigDir/ws/.local/myx/myx.distro-.local/sh-lib"
	ln -s "$rigLocalContext" "$rigDir/ws/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
	ln -s "$MDLT_ORIGIN/myx/myx.common" "$rigDir/ws/.local/myx/myx.common"
}
rigRun(){ ## umask, result file, op and arguments...
	local runMask="$1" runOut="$2" ; shift 2
	env -i HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_MASK="$runMask" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			umask "$RIG_MASK" ; cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}

echo "-- the installer under umask 077, creating the files --"
rigScenario create
rigRun 077 "$rigDir/i" --install-vscode-integrations
rigAssert "it registered all three MCP configs"        "$( LC_ALL=C grep -c -E '^🔌 myx.common registered in (\.local/agents/mcp\.servers\.json|\.vscode/mcp\.json|\.mcp\.json)$' "$rigDir/i" || : )" 3
rigAssert ".local/agents/mcp.servers.json is 0644"     "$( rigMode "$rigDir/ws/.local/agents/mcp.servers.json" )" "-rw-r--r--"
rigAssert ".vscode/mcp.json is 0644"                   "$( rigMode "$rigDir/ws/.vscode/mcp.json" )" "-rw-r--r--"
rigAssert ".mcp.json is 0644"                          "$( rigMode "$rigDir/ws/.mcp.json" )" "-rw-r--r--"
rigAssert "~/.claude.json is 0600"                     "$( rigMode "$rigDir/home/.claude.json" )" "-rw-------"

echo "-- the installer under umask 077, finding a config already at 0600 --"
rigScenario existing
## Twice first: only from the second install on is the content stable, so the third
## takes the unchanged-content branch, the one that must still set the mode.
rigRun 077 "$rigDir/i1" --install-vscode-integrations
rigRun 077 "$rigDir/i1" --install-vscode-integrations
cp "$rigDir/ws/.mcp.json" "$rigDir/mcp.before"
chmod 600 "$rigDir/ws/.mcp.json"
rigRun 077 "$rigDir/i2" --install-vscode-integrations
rigAssert "the install left its content unchanged"    "$( cmp -s "$rigDir/mcp.before" "$rigDir/ws/.mcp.json" && printf same || printf changed )" same
rigAssert "an unchanged config is still made 0644"     "$( rigMode "$rigDir/ws/.mcp.json" )" "-rw-r--r--"

echo "-- the self-test --"
rigScenario selftest
rigRun 022 "$rigDir/s0" --owner-credential-store-self-test
rigAssert "every file absent: rc 0"                    "$( cat "$rigDir/s0.rc" )" 0
rigAssert "and each absence is stated"                 "$( LC_ALL=C grep -c 'is absent, so its mode 0[0-9]* is not asserted' "$rigDir/s0" || : )" 4
rigRun 077 "$rigDir/i" --install-vscode-integrations
rigRun 022 "$rigDir/s1" --owner-credential-store-self-test
rigAssert "the installed modes pass, rc 0"             "$( cat "$rigDir/s1.rc" ):$( rigHolds "$rigDir/s1" 'PASSED' )" "0:yes"
chmod 644 "$rigDir/home/.claude.json"
rigRun 022 "$rigDir/s2" --owner-credential-store-self-test
rigAssert "~/.claude.json at 0644 fails, rc 1"         "$( cat "$rigDir/s2.rc" )" 1
rigAssert "naming it and the mode claimed"             "$( rigHolds "$rigDir/s2" "$rigDir/home/.claude.json is 0644, and this package claims 0600 for it" )" yes
chmod 600 "$rigDir/home/.claude.json"
chmod 600 "$rigDir/ws/.vscode/mcp.json"
rigRun 022 "$rigDir/s3" --owner-credential-store-self-test
rigAssert "an MCP config at 0600 fails, rc 1"          "$( cat "$rigDir/s3.rc" )" 1
rigAssert "naming it and the mode claimed"             "$( rigHolds "$rigDir/s3" "$rigDir/ws/.vscode/mcp.json is 0600, and this package claims 0644 for it" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP FILE MODES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_FILE_MODES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
