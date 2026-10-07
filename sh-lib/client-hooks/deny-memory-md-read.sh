#!/bin/bash
## deny-memory-md-read.sh -- the PreToolUse hook that denies READING the client's own
## machine-local memory store, ~/.claude/projects/<project>/memory/ (and the
## $CLAUDE_CONFIG_DIR equivalent): Read of any file in it, MEMORY.md and every topic file,
## and a Glob or Grep pointed into it. Every other call is allowed. A REAL SCRIPT:
## installed by copying, runs exactly as it stands, nothing substituted into it.
##
## THIS IS NOT A REROUTE, and it is deliberately not part of deny-native-tool-reroute.sh.
## That one is unconditional and never reads the payload. This one is CONDITIONAL: it
## reads the payload, matches one store in it, and has an allow path.
##
## Sibling to protect-memory-md.sh, which covers Edit and Write, and decides a path the
## same way: by its spelling (for directories that do not exist), by its resolved location
## (the nearest existing directory followed through every symlink, so `..` and a linked
## directory are seen through), and against every file in the store with -ef (a hard or
## symbolic link elsewhere). The tool comes from the payload's tool_name, else $1.
##   Read -- file_path. MEMORY.md is also matched on the raw payload, as it always was.
##   Glob -- path (else cwd) joined with pattern: refused when the pattern's literal base
##           lies in the store, or holds a store its remaining segments can reach.
##   Grep -- path (else cwd): refused when it lies in the store or holds one, since a
##           search recurses into every directory under its path.
##
## Builtins only, nothing read from PATH: an absent jq or cat left the path empty, matched
## nothing and exited 0, which a *-native client reads as ALLOW -- so the guard silently
## stopped guarding on any host without them.
##
## It exists at all because the plain permissions.deny array cannot carry a reason, and a
## refusal with no reason sends the caller nowhere. \uXXXX and an escaped cwd are not decoded.

IFS= read -r -d '' hookInput

## One JSON string member's value, decoded, into hookValue; empty when absent.
HookField(){ ## member name
	local fieldRest="${hookInput#*\"$1\"}"
	hookValue=""
	[ "$fieldRest" != "$hookInput" ] || return 0
	fieldRest="${fieldRest#*\"}"
	while [ -n "$fieldRest" ] ; do
		case "$fieldRest" in
			\\\"*) hookValue="$hookValue\"" ; fieldRest="${fieldRest:2}" ;;
			\\\\*) hookValue="$hookValue\\" ; fieldRest="${fieldRest:2}" ;;
			\\/*)  hookValue="$hookValue/" ; fieldRest="${fieldRest:2}" ;;
			\"*)   break ;;
			*)     hookValue="$hookValue${fieldRest:0:1}" ; fieldRest="${fieldRest:1}" ;;
		esac
	done
}

## Relative paths are the payload's own cwd's, else this hook's.
hookCwd="${hookInput#*\"cwd\"}"
if [ "$hookCwd" != "$hookInput" ] ; then hookCwd="${hookCwd#*\"}" ; hookCwd="${hookCwd%%\"*}" ; else hookCwd="$PWD" ; fi
HookAbsolute(){ ## path -- into hookValue
	hookValue="$1"
	[ -z "$hookValue" ] || [ "${hookValue#/}" != "$hookValue" ] || hookValue="$hookCwd/$hookValue"
}

## Every memory directory on this machine, resolved, one per line.
hookStores=""
for hookStore in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/memory "$HOME"/.claude/projects/*/memory ; do
	[ -d "$hookStore" ] || continue
	hookStoreReal="$( cd -P "$hookStore" 2>/dev/null && pwd -P )" || continue
	hookStores="$hookStores$hookStoreReal"$'\n'
done

## The resolved location of a path whose tail may not exist yet, into hookReal.
HookResolve(){ ## absolute path
	local resolveDir="${1%/*}" resolveTail="${1##*/}"
	[ -n "$resolveTail" ] || resolveTail="."
	while [ -n "$resolveDir" ] && [ ! -d "$resolveDir" ] ; do
		resolveTail="${resolveDir##*/}/$resolveTail" ; resolveDir="${resolveDir%/*}"
	done
	hookReal="$( cd -P "${resolveDir:-/}" 2>/dev/null && pwd -P )" && hookReal="${hookReal%/}/$resolveTail" || hookReal=""
	hookReal="${hookReal%/.}"
	## A tail that is itself an existing directory is resolved through, so a linked one is seen.
	if [ -d "$hookReal" ] ; then hookReal="$( cd -P "$hookReal" 2>/dev/null && pwd -P )" || hookReal="" ; fi
}

## Zero when the path lies in a memory store.
HookInStore(){ ## absolute path
	local inStore inFile
	case "$1" in
		*/.claude/projects/*/memory|*/.claude/projects/*/memory/*) return 0 ;;
	esac
	HookResolve "$1"
	while IFS= read -r inStore ; do
		[ -n "$inStore" ] || continue
		case "$hookReal" in "$inStore"|"$inStore"/*) return 0 ;; esac
		for inFile in "$inStore"/* ; do
			[ -e "$inFile" ] || continue
			[ ! "$1" -ef "$inFile" ] || return 0
		done
	done <<< "$hookStores"
	return 1
}

## Zero when a memory store lies under the path. With a pattern rest, only a store the
## rest's segments can reach: `**` reaches any, otherwise each segment must match.
HookHoldsStore(){ ## absolute path, [pattern rest]
	local holdStore holdRel holdRest holdSeg holdPat
	HookResolve "$1"
	[ -n "$hookReal" ] || return 1
	while IFS= read -r holdStore ; do
		[ -n "$holdStore" ] || continue
		case "$holdStore/" in "${hookReal%/}"/*) ;; *) continue ;; esac
		[ "$#" -ge 2 ] || return 0
		holdRel="${holdStore#"${hookReal%/}"/}" ; holdRest="$2"
		while [ -n "$holdRel" ] ; do
			holdPat="${holdRest%%/*}"
			case "$holdPat" in *'**'*) return 0 ;; esac
			holdSeg="${holdRel%%/*}"
			[[ "$holdSeg" == $holdPat ]] || continue 2
			## A pattern ending here lists this entry by name and reaches nothing inside it.
			[ "$holdRest" != "$holdPat" ] || continue 2
			[ "$holdRel" != "$holdSeg" ] || return 0
			holdRel="${holdRel#*/}" ; holdRest="${holdRest#*/}"
		done
	done <<< "$hookStores"
	return 1
}

HookField tool_name ; hookTool="${hookValue:-${1:-Read}}"
hookDenied=""
case "$hookTool" in
	Glob)
		HookField path ; HookAbsolute "${hookValue:-$hookCwd}" ; hookBase="$hookValue"
		HookField pattern ; hookPattern="$hookValue"
		case "$hookPattern" in
			/*) hookFull="$hookPattern" ;;
			*)  hookFull="${hookBase%/}/$hookPattern" ;;
		esac
		## The literal base: every leading segment with no glob character in it.
		hookLiteral="" ; hookRest="${hookFull#/}"
		while [ -n "$hookRest" ] ; do
			hookSeg="${hookRest%%/*}"
			case "$hookSeg" in *[\*\?\[\{]*) break ;; esac
			hookLiteral="$hookLiteral/$hookSeg"
			[ "$hookRest" != "$hookSeg" ] || { hookRest="" ; break ; }
			hookRest="${hookRest#*/}"
		done
		case "$hookFull" in
			*/.claude/projects/*/memory|*/.claude/projects/*/memory/*) hookDenied=1 ;;
		esac
		[ -n "$hookDenied" ] || ! HookInStore "${hookLiteral:-/}" || hookDenied=1
		if [ -z "$hookDenied" ] && [ -n "$hookRest" ] ; then
			! HookHoldsStore "${hookLiteral:-/}" "$hookRest" || hookDenied=1
		fi
	;;
	Grep)
		HookField path ; HookAbsolute "${hookValue:-$hookCwd}"
		if HookInStore "$hookValue" || HookHoldsStore "$hookValue" ; then hookDenied=1 ; fi
	;;
	*)
		HookField file_path ; HookAbsolute "$hookValue" ; hookPath="$hookValue"
		## Decided on the resolved file (-ef against every account's MEMORY.md), with the spelling match kept for paths that do not exist.
		if [ -n "$hookPath" ] ; then
			for hookIndex in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/memory/MEMORY.md "$HOME"/.claude/projects/*/memory/MEMORY.md ; do
				[ -e "$hookIndex" ] || continue
				if [ "$hookPath" -ef "$hookIndex" ] ; then hookDenied=1 ; break ; fi
			done
			[ -n "$hookDenied" ] || ! HookInStore "$hookPath" || hookDenied=1
		fi
		## The closing quote anchors the end of the JSON string value, so a path that merely
		## starts with it (MEMORY.md.bak) is not matched.
		[[ "$hookInput" != *'/.claude/projects/'*'/memory/MEMORY.md"'* ]] || hookDenied=1
	;;
esac

if [ -n "$hookDenied" ] ; then
	printf '{\n'
	printf '\t"hookSpecificOutput": {\n'
	printf '\t\t"hookEventName": "PreToolUse",\n'
	printf '\t\t"permissionDecision": "deny",\n'
	printf '\t\t"permissionDecisionReason": "the machine-local agent memory is not team knowledge and is never read or searched (a search whose path holds it is refused too: narrow the path). Team knowledge is in the workspace, repository and project MAGIC.md, the skillset and your inbox. Record what you learn the team way: a lesson as a reflection-* in your own inbox (--member-inbox-reflection-upsert); a fact for another member as an inbox note or inquiry (--member-inbox-note-upsert, --member-upsert-member-inquiry); a decision, permission or problem as an escalation (AskUserQuestion to the session magic-coordinator); a repo or workspace finding in that MAGIC.md"\n'
	printf '\t}\n'
	printf '}\n'
	exit 0
fi

exit 0
