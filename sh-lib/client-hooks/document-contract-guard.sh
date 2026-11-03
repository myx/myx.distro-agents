#!/usr/bin/env bash
## document-contract-guard.sh -- the PreToolUse hook of the document-contract guard: a Write, Edit or
## MultiEdit whose path is a registered document type is checked against its contract. Class `native`
## (AgentsTools.ClientToolPolicy.include): the harness makes the same decision itself in its own Write and
## Edit tools, so the hook never runs there. A REAL SCRIPT: installed by copying, runs exactly as it
## stands, nothing substituted into it.
##
## THE DEFAULT ALLOWS. A payload this cannot read, a tool it does not decide, or a path with no
## registered extension: exit 0, no output -- a *-native client reads silence as allow. Only a refusing
## fault the write introduces is denied. The decision is the one the harness door uses
## (AgentsTools.DocGuard.include), with the after document built here: a Write has it in its content, and
## an Edit or MultiEdit applies its own edits to the file as it stands, once. It depends on no network,
## lock or store.

IFS= read -r -d '' hookInput

## The string value of the first "<key>": in the text given, into hookValue; rc 1 where absent, not a
## string, or carrying an escape this does not decode. Builtins only. \n, \t, \r, \", \\ and \/ decode.
hookString(){ ## text, key
	local stringRest="${1#*\"$2\"}"
	hookValue=""
	[ "$stringRest" != "$1" ] || return 1
	while [ -n "$stringRest" ] ; do
		case "$stringRest" in
			' '*|$'\t'*|$'\n'*|$'\r'*) stringRest="${stringRest:1}" ;;
			*) break ;;
		esac
	done
	case "$stringRest" in :*) stringRest="${stringRest:1}" ;; *) return 1 ;; esac
	while [ -n "$stringRest" ] ; do
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
			\\n*)  hookValue="$hookValue"$'\n' ; stringRest="${stringRest:2}" ;;
			\\t*)  hookValue="$hookValue"$'\t' ; stringRest="${stringRest:2}" ;;
			\\r*)  hookValue="$hookValue"$'\r' ; stringRest="${stringRest:2}" ;;
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
case "$hookToolName" in
	Edit|Write|MultiEdit) ;;
	*) exit 0 ;;
esac

hookArgs="${hookInput#*\"tool_input\"}"
[ "$hookArgs" != "$hookInput" ] || exit 0
hookString "$hookArgs" file_path || exit 0
hookPath="$hookValue"
[ -n "$hookPath" ] || exit 0

## A relative path resolves against the payload cwd, else this hook's own.
if [ "${hookPath#/}" = "$hookPath" ] ; then
	hookCwd="${hookInput#*\"cwd\"}"
	if [ "$hookCwd" != "$hookInput" ] ; then hookCwd="${hookCwd#*\"}" ; hookCwd="${hookCwd%%\"*}" ; else hookCwd="$PWD" ; fi
	hookPath="$hookCwd/$hookPath"
fi

hookWs="${MMDAPP:-${CLAUDE_PROJECT_DIR:-}}"
hookWs="${hookWs%/}"
MDLT_ORIGIN="${MDLT_ORIGIN:-$hookWs/.local}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.DocGuard.include" 2>/dev/null || exit 0

## The document as it stands, and as it would be. A Write has its after in content; an Edit applies its
## edits to the file, as the harness does, once.
hookBefore="$( cat -- "$hookPath" 2>/dev/null )" || hookBefore=""
hookAfter=""
case "$hookToolName" in
	Write)
		hookString "$hookArgs" content || exit 0
		hookAfter="$hookValue"
	;;
	Edit|MultiEdit)
		hookString "$hookArgs" old_string || exit 0 ; hookOld="$hookValue"
		hookString "$hookArgs" new_string || exit 0 ; hookNew="$hookValue"
		hookString "$hookArgs" replace_all || hookAll=""
		[ "$hookAll" = "true" ] && hookAll=1 || hookAll=""
		[ -n "$hookBefore" ] || exit 0
		hookAfter="$( printf '%s' "$hookBefore" | OLD="$hookOld" NEW="$hookNew" ALL="$hookAll" LC_ALL=C awk -v RS=$'\001' '
			BEGIN { editOld = ENVIRON["OLD"] ; editNew = ENVIRON["NEW"] ; editAll = ENVIRON["ALL"] ; editDone = 0 ; }
			{
				outText = "" ; scanRest = $0
				while ( ( editAll != "" || !editDone ) && ( matchPos = index(scanRest, editOld) ) > 0 ) {
					outText = outText substr(scanRest, 1, matchPos - 1) editNew
					scanRest = substr(scanRest, matchPos + length(editOld)) ; editDone = 1
				}
				if (NR > 1) printf "%s", RS
				printf "%s%s", outText, scanRest
			}
		' )" || exit 0
	;;
esac

## The decision's refusal reason, on its stderr; silence with a clean exit allows.
hookReason="$( AgentsToolsDocGuardDecide "$hookPath" "$hookBefore" "$hookAfter" hook 2>&1 > /dev/null )" && exit 0
[ -n "$hookReason" ] || hookReason="the document-contract guard refused the write"

printf '{\n'
printf '\t"hookSpecificOutput": {\n'
printf '\t\t"hookEventName": "PreToolUse",\n'
printf '\t\t"permissionDecision": "deny",\n'
printf '\t\t"permissionDecisionReason": "%s"\n' "$hookReason"
printf '\t}\n'
printf '}\n'
exit 0
