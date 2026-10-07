#!/bin/bash
## protect-memory-md.sh -- the PreToolUse hook that denies Edit and Write into the client's
## own machine-local memory store, ~/.claude/projects/<project>/memory/ (MEMORY.md and every
## topic file beside it), and allows every other write. A REAL SCRIPT: installed by copying,
## runs exactly as it stands, nothing substituted into it.
##
## A CONDITIONAL GUARD, not a reroute: it reads the payload, matches one thing in it, and
## allows everything else. Class `all` in AgentsTools.ClientToolPolicy.include, so our own
## universal harness applies it too: its roots never include that store, but a granted
## escalation can widen a call past them, and the subject is the same whichever client asks.
##
## The machine-local memory is not team knowledge -- not team-data, the skillset, Jira or
## Confluence -- so the refusal names where a finding goes instead.
##
## Decided on file_path alone, never on the whole payload: a Write carries its content, and
## content that merely mentions a memory path is not a write into one.
##
## Builtins only, nothing read from PATH: an absent parser leaves the path empty, matches
## nothing and exits 0, which a *-native client reads as ALLOW. \uXXXX and an escaped cwd
## are not decoded.

IFS= read -r -d '' hookInput

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
	## The spelling, for a path whose directories do not exist yet.
	case "$hookPath" in
		*/.claude/projects/*/memory|*/.claude/projects/*/memory/*) hookDenied=1 ;;
	esac
	## The resolved location: the nearest existing directory above the path, followed
	## through every symlink, against every account's memory directory resolved the same way.
	if [ -z "$hookDenied" ] ; then
		hookDir="${hookPath%/*}" ; hookTail="${hookPath##*/}"
		while [ -n "$hookDir" ] && [ ! -d "$hookDir" ] ; do
			hookTail="${hookDir##*/}/$hookTail" ; hookDir="${hookDir%/*}"
		done
		hookReal="$( cd -P "${hookDir:-/}" 2>/dev/null && pwd -P )" && hookReal="${hookReal%/}/$hookTail" || hookReal=""
		for hookMemory in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/memory "$HOME"/.claude/projects/*/memory ; do
			[ -d "$hookMemory" ] || continue
			hookMemoryReal="$( cd -P "$hookMemory" 2>/dev/null && pwd -P )" || continue
			case "$hookReal" in
				"$hookMemoryReal"|"$hookMemoryReal"/*) hookDenied=1 ; break ;;
			esac
			## An existing file elsewhere that IS one in the store (a hard or symbolic link).
			for hookMemoryFile in "$hookMemory"/* ; do
				[ -e "$hookMemoryFile" ] || continue
				if [ "$hookPath" -ef "$hookMemoryFile" ] ; then hookDenied=1 ; break 2 ; fi
			done
		done
	fi
fi

if [ -n "$hookDenied" ] ; then
	printf '{\n'
	printf '\t"hookSpecificOutput": {\n'
	printf '\t\t"hookEventName": "PreToolUse",\n'
	printf '\t\t"permissionDecision": "deny",\n'
	printf '\t\t"permissionDecisionReason": "the machine-local agent memory is not team knowledge and is never written. Record it the team way instead: a lesson as a reflection-* in your own inbox (--member-inbox-reflection-upsert); a fact for another member as an inbox note or inquiry (--member-inbox-note-upsert, --member-upsert-member-inquiry); a decision, permission or problem as an escalation (AskUserQuestion to the session magic-coordinator); a repo or workspace finding in that MAGIC.md"\n'
	printf '\t}\n'
	printf '}\n'
	exit 0
fi

exit 0
