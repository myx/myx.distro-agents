#!/bin/bash
## allow-granted-native-tool.sh -- the PreToolUse hook that answers allow for a native file
## tool call a spawned member is granted, so a *-native client runs it with no permission
## prompt. A REAL SCRIPT: installed by copying, runs exactly as it stands, nothing
## substituted into it.
##
## Only in a spawned member session: MDAT_SPAWN_AGENT names the acting member. The human
## own session carries no spawn identity and gets no answer from here, as before.
##
## Read, Edit, Write, MultiEdit, NotebookEdit, Grep and Glob, the tool read from the payload
## tool_name; MultiEdit and NotebookEdit are decided as Edit, Grep and Glob by their search
## root (the payload cwd when no path is given). The decision is the one the harness gate
## makes: the session permission index of the member (AgentsTools.Grants.include), by
## builtins only, rebuilt with one awk only when stale, the ceiling first:
##   granted                     allow
##   a write in a read-only place deny, naming where to write instead
##   anything else               no answer: the call goes on exactly as before this hook --
##                               the rules of the client, then the PermissionRequest hook
##                               (permission-request-escalation.sh), which decides it
##                               through the tooling and records a refusal it denies.
## An Allow once is used up through the tooling, as the harness gate does, and allows only
## when that succeeds. Every deny of another hook stands: a deny wins over this allow, and
## a path in the machine-local memory store is never answered here at all.
##
## Class `native` in AgentsTools.ClientToolPolicy.include: our own universal harness makes
## this same decision itself, so it never runs this hook.
##
## Payload strings are read by builtins; one carrying an escape other than \" \\ \/ is not
## decoded and gets no answer, so a path is never guessed.

IFS= read -r -d '' hookInput

hookMember="${MDAT_SPAWN_AGENT:-}"
[ -n "$hookMember" ] || exit 0
case "$hookMember" in */*|.|..) exit 0 ;; esac
hookWs="${MMDAPP:-${CLAUDE_PROJECT_DIR:-}}"
hookWs="${hookWs%/}"
[ -n "$hookWs" ] && [ -d "$hookWs" ] || exit 0
MDLT_ORIGIN="${MDLT_ORIGIN:-$hookWs/.local}"
hookLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
[ -f "$hookLib/AgentsTools.Grants.include" ] || exit 0

## The string value of the first "<key>": in the text given, into hookValue; rc 1 when
## absent, not a string, or carrying an escape this does not decode.
hookString(){ ## text, key
	local stringRest="${1#*\"$2\"}"
	hookValue=""
	[ "$stringRest" != "$1" ] || return 1
	while : ; do
		case "$stringRest" in
			' '*|$'\t'*|$'\n'*|$'\r'*) stringRest="${stringRest:1}" ;;
			*) break ;;
		esac
	done
	case "$stringRest" in :*) stringRest="${stringRest:1}" ;; *) return 1 ;; esac
	while : ; do
		case "$stringRest" in
			' '*|$'\t'*|$'\n'*|$'\r'*) stringRest="${stringRest:1}" ;;
			*) break ;;
		esac
	done
	case "$stringRest" in \"*) stringRest="${stringRest:1}" ;; *) return 1 ;; esac
	while [ -n "$stringRest" ] ; do
		case "$stringRest" in
			\\\"*) hookValue="$hookValue\"" ; stringRest="${stringRest:2}" ;;
			\\\\*) hookValue="$hookValue\\" ; stringRest="${stringRest:2}" ;;
			\\/*)  hookValue="$hookValue/" ; stringRest="${stringRest:2}" ;;
			\\*)   hookValue="" ; return 1 ;;
			\"*)   return 0 ;;
			*)     hookValue="$hookValue${stringRest:0:1}" ; stringRest="${stringRest:1}" ;;
		esac
	done
	hookValue=""
	return 1
}

hookString "$hookInput" tool_name || exit 0
hookToolName="$hookValue"
hookArgs="${hookInput#*\"tool_input\"}"
[ "$hookArgs" != "$hookInput" ] || exit 0
hookTarget=""
case "$hookToolName" in
	Read|Edit|Write|MultiEdit) hookTool="$hookToolName" ; [ "$hookTool" != MultiEdit ] || hookTool=Edit ; hookString "$hookArgs" file_path || exit 0 ; hookTarget="$hookValue" ;;
	NotebookEdit) hookTool=Edit ; hookString "$hookArgs" notebook_path || exit 0 ; hookTarget="$hookValue" ;;
	Grep|Glob) hookTool="$hookToolName" ; ! hookString "$hookArgs" path || hookTarget="$hookValue" ;;
	*) exit 0 ;;
esac
## A relative path, or none for a search: the payload cwd, else this hook own.
if [ "${hookTarget#/}" = "$hookTarget" ] ; then
	hookCwd="$PWD"
	! hookString "$hookInput" cwd || hookCwd="$hookValue"
	if [ -z "$hookTarget" ] ; then hookTarget="$hookCwd" ; else hookTarget="${hookCwd%/}/$hookTarget" ; fi
fi
case "$hookTarget" in /*) ;; *) exit 0 ;; esac
case "/$hookTarget/" in */../*|*/./*) exit 0 ;; esac

## Resolved as the harness gate resolves it: the directory itself, or its parent, through
## `cd -P`, then every link the last name is; a path that cannot be resolved as given.
if [ -d "$hookTarget" ] ; then
	hookReal="$( cd "$hookTarget" 2>/dev/null && pwd -P )" || hookReal=""
else
	hookDir="${hookTarget%/*}" ; [ -n "$hookDir" ] || hookDir="/"
	hookReal="$( cd "$hookDir" 2>/dev/null && pwd -P )" || hookReal=""
	[ -z "$hookReal" ] || hookReal="${hookReal%/}/${hookTarget##*/}"
fi
[ -n "$hookReal" ] || hookReal="$hookTarget"
hookHops=0
while [ -L "$hookReal" ] && [ -e "$hookReal" ] ; do
	hookHops=$(( hookHops + 1 ))
	[ "$hookHops" -le 40 ] || exit 0
	hookLink="$( readlink "$hookReal" 2>/dev/null )" || exit 0
	[ -n "$hookLink" ] || exit 0
	case "$hookLink" in /*) ;; *) hookLink="${hookReal%/*}/$hookLink" ;; esac
	hookDir="${hookLink%/*}" ; [ -n "$hookDir" ] || hookDir="/"
	hookReal="$( cd "$hookDir" 2>/dev/null && pwd -P )" || exit 0
	hookReal="${hookReal%/}/${hookLink##*/}"
done
## The machine-local memory store is the memory guards' alone.
case "$hookReal" in */.claude/projects/*/memory|*/.claude/projects/*/memory/*) exit 0 ;; esac

## The session, its sandbox and this origin, as the harness gate hands them to the index,
## so the two share one session index rather than rebuilding it in turn.
hookSession="${MDAT_SPAWN_SESSION_ID:-}"
[ -n "$hookSession" ] || ! hookString "$hookInput" session_id || hookSession="$hookValue"
case "$hookSession" in */*|.|..) hookSession="" ;; esac
hookIn="" hookOut=""
if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
	if [ -n "${MDAT_SPAWN_SANDBOX_ROOT_REAL:-}" ] && [ "${MDAT_SPAWN_SANDBOX_ROOT_REAL#/}" != "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ "$MDAT_SPAWN_SANDBOX_ROOT" -ef "$MDAT_SPAWN_SANDBOX_ROOT_REAL" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" ] \
		&& [ -d "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] && [ ! -L "$MDAT_SPAWN_SANDBOX_ROOT_REAL/output" ] ; then
		hookIn="$MDAT_SPAWN_SANDBOX_ROOT_REAL/input" hookOut="$MDAT_SPAWN_SANDBOX_ROOT_REAL/output"
	else
		hookIn="$( cd "$MDAT_SPAWN_SANDBOX_ROOT/input" 2>/dev/null && pwd -P )" || hookIn="$MDAT_SPAWN_SANDBOX_ROOT/input"
		hookOut="$( cd "$MDAT_SPAWN_SANDBOX_ROOT/output" 2>/dev/null && pwd -P )" || hookOut="$MDAT_SPAWN_SANDBOX_ROOT/output"
	fi
fi

. "$hookLib/AgentsTools.Grants.include" || exit 0
AgentsToolsGrantsSessionEnsure "$hookWs" "$hookMember" "$hookSession" "$hookIn" "$hookOut" "$MDLT_ORIGIN/myx/myx.distro-agents/skillset" 2>/dev/null || exit 0
hookRc=0
AgentsToolsGrantsSessionCheck "$hookTool" "$hookReal" "$hookWs/.local/agents/sessions/$hookSession" || hookRc=$?

## One JSON string, escaped for a document: backslash, quote, and the control characters a path may hold.
hookJson(){ ## text
	local jsonText="${1//\\/\\\\}"
	jsonText="${jsonText//\"/\\\"}"
	jsonText="${jsonText//$'\n'/\\n}"
	jsonText="${jsonText//$'\t'/\\t}"
	jsonText="${jsonText//$'\r'/\\r}"
	printf '%s' "$jsonText"
}
hookAnswer(){ ## allow|deny, reason
	printf '{\n'
	printf '\t"hookSpecificOutput": {\n'
	printf '\t\t"hookEventName": "PreToolUse",\n'
	printf '\t\t"permissionDecision": "%s",\n' "$1"
	printf '\t\t"permissionDecisionReason": "%s"\n' "$( hookJson "$2" )"
	printf '\t}\n'
	printf '}\n'
	exit 0
}

case "$hookRc" in
	0)
		if [ -n "$agentsGrantsCheckOnce" ] ; then
			[ -n "$hookSession" ] || exit 0
			"$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-consume \
				--session-id "$hookSession" --refusal-id "$agentsGrantsCheckOnce" > /dev/null 2>&1 || exit 0
		fi
		hookAnswer allow "granted to $hookMember: $agentsGrantsCheckLayer"
	;;
	3)
		if [ -n "$hookOut" ] ; then
			hookAnswer deny "$agentsGrantsCheckPlace is a read-only place, so nothing is written there: $hookTarget -- write to your session sandbox output/ instead, or a folder under it: $hookOut/"
		fi
		hookAnswer deny "$agentsGrantsCheckPlace is a read-only place, so nothing is written there: $hookTarget -- find another suitable location"
	;;
esac
exit 0
