#!/bin/bash
## deny-memory-md-read.sh -- the PreToolUse hook that denies Read on the memory system's
## own MEMORY.md index, and allows every other Read. A REAL SCRIPT: installed by copying,
## runs exactly as it stands, nothing substituted into it.
##
## THIS IS NOT A REROUTE, and it is deliberately not part of deny-native-tool-reroute.sh.
## That one is unconditional and never reads the payload. This one is CONDITIONAL: it
## reads the payload, matches one path in it, and has an allow path. Folding it in would
## put payload parsing into a script with no business with payloads, and an allow path
## into a script whose whole point is that it never allows.
##
## Sibling to protect-memory-md.sh, which covers Edit and Write -- kept as its own file so
## that already-verified script is never touched by an unrelated change.
##
## Builtins only, nothing read from PATH: an absent jq or cat left the path empty, matched
## nothing and exited 0, which a *-native client reads as ALLOW -- so the guard silently
## stopped guarding on any host without them.
##
## It exists at all because the plain permissions.deny array cannot carry a reason, and a
## refusal with no reason sends the caller nowhere.

IFS= read -r -d '' hookInput

## Decided on the resolved file (-ef against every account's MEMORY.md), with the spelling match kept for paths that do not exist; \uXXXX and an escaped cwd are not decoded.
hookPath="${hookInput#*\"file_path\"}"
if [ "$hookPath" != "$hookInput" ] ; then
	hookPath="${hookPath#*\"}"
	hookValue=""
	while [ -n "$hookPath" ] ; do
		case "$hookPath" in
			\\\"*) hookValue="$hookValue\"" ; hookPath="${hookPath:2}" ;;
			\\\\*) hookValue="$hookValue\\" ; hookPath="${hookPath:2}" ;;
			\\/*)  hookValue="$hookValue/" ; hookPath="${hookPath:2}" ;;
			\"*)   break ;;
			*)     hookValue="$hookValue${hookPath:0:1}" ; hookPath="${hookPath:1}" ;;
		esac
	done
	hookPath="$hookValue"
else
	hookPath=""
fi
if [ -n "$hookPath" ] && [ "${hookPath#/}" = "$hookPath" ] ; then
	## Relative: the payload's own cwd, else this hook's.
	hookCwd="${hookInput#*\"cwd\"}"
	if [ "$hookCwd" != "$hookInput" ] ; then hookCwd="${hookCwd#*\"}" ; hookCwd="${hookCwd%%\"*}" ; else hookCwd="$PWD" ; fi
	hookPath="$hookCwd/$hookPath"
fi
hookDenied=""
if [ -n "$hookPath" ] ; then
	for hookIndex in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/memory/MEMORY.md "$HOME"/.claude/projects/*/memory/MEMORY.md ; do
		[ -e "$hookIndex" ] || continue
		if [ "$hookPath" -ef "$hookIndex" ] ; then hookDenied=1 ; break ; fi
	done
fi

## The closing quote anchors the end of the JSON string value, so a path that merely
## starts with it (MEMORY.md.bak) is not matched.
if [ -n "$hookDenied" ] || [[ "$hookInput" == *'/.claude/projects/'*'/memory/MEMORY.md"'* ]]; then
	printf '{\n'
	printf '\t"hookSpecificOutput": {\n'
	printf '\t\t"hookEventName": "PreToolUse",\n'
	printf '\t\t"permissionDecision": "deny",\n'
	printf '\t\t"permissionDecisionReason": "read workspace, repository and project MAGIC.md"\n'
	printf '\t}\n'
	printf '}\n'
	exit 0
fi

exit 0
