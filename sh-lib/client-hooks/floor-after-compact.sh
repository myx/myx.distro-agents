#!/usr/bin/env bash
##
## floor-after-compact.sh -- re-serves the floor of a SPAWNED native session after its client compacted the conversation. A compaction
## replaces the history with a summary, so what the member loaded on its way to armed (the team's armed file, its own armed file) may be gone
## from its context. The pointer below tells it to load them again. Nothing is served for a session the tooling did not spawn (no
## MDAT_SPAWN_AGENT), for a member name that is no bare name, and nothing is ever refused: always exit 0.
##
##   serve                Claude Code, SessionStart with the matcher `compact`: what this prints on stdout is added to the context.
##   mark                 Grok Build's PostCompact and Copilot CLI's preCompact: the floor is dropped from now. Neither event can add context, so
##                        a marker is kept in the session's store (floor-dropped), and nothing goes to stdout.
##   grok                 Grok Build's PreToolUse: once, after a mark, the pointer as `additionalContext`; then the marker goes.
##   copilot              Copilot CLI's postToolUse: once, after a mark, the pointer as `additionalContext`; then the marker goes.
##   config grok|copilot  The hook file for ~/.grok/hooks/ or ~/.copilot/hooks/, printed. It is never written here: it is put in place by the owner.
##
## The files named are the floor every native member loads: the team's armed file and the member's own (the Skill tool serves them). The
## harness has no such hook: it re-sends its team layer at every request and builds the member layer again at a restart.
##
set -u
floorMember="${MDAT_SPAWN_AGENT:-}"
floorSession="${MDAT_SPAWN_SESSION_ID:-}"
floorHook="${BASH_SOURCE[0]}"

floorNameOk(){ ## text -- a bare name: letters, digits, dot, dash, underscore
	case "${1:-}" in ''|*[!A-Za-z0-9._-]*|.|..) return 1 ;; esac
	return 0
}
floorText(){ ## the pointer, one line a sentence, or nothing where there is no member
	floorNameOk "$floorMember" || return 1
	printf 'Your conversation was just compacted, and what you loaded before it may be gone. Load your floor again before you act, with the Skill tool: magic-team (file magic-team.armed.md), then %s (file %s.armed.md). Then carry on with your task.' "$floorMember" "$floorMember"
}
floorMarker(){ ## the marker file, or nothing
	floorNameOk "$floorSession" && [ -n "${MMDAPP:-}" ] || return 1
	printf '%s' "$MMDAPP/.local/agents/sessions/$floorSession/floor-dropped"
}
floorJson(){ ## text -- a JSON string, quoted (the text has no quote, backslash or control character but what this adds)
	printf '"%s"' "$1"
}

floorMode="${1:-}"
case "$floorMode" in
	serve)
		cat > /dev/null
		floorText || exit 0
		printf '\n'
	;;
	mark)
		cat > /dev/null
		floorNameOk "$floorMember" || exit 0
		floorFile="$( floorMarker )" || exit 0
		mkdir -p "${floorFile%/*}" 2> /dev/null && : > "$floorFile" 2> /dev/null
	;;
	grok|copilot)
		cat > /dev/null
		floorFile="$( floorMarker )" || exit 0
		[ -f "$floorFile" ] || exit 0
		floorBody="$( floorText )" || exit 0
		rm -f "$floorFile" 2> /dev/null || exit 0
		if [ "$floorMode" = grok ] ; then
			printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":%s}}\n' "$( floorJson "$floorBody" )"
		else
			printf '{"additionalContext":%s}\n' "$( floorJson "$floorBody" )"
		fi
	;;
	config)
		case "${2:-}" in
			grok)
				printf '{\n  "hooks": {\n    "PostCompact": [ { "hooks": [ { "type": "command", "command": "%s mark" } ] } ],\n    "PreToolUse": [ { "hooks": [ { "type": "command", "command": "%s grok" } ] } ]\n  }\n}\n' "$floorHook" "$floorHook"
			;;
			copilot)
				printf '{\n  "version": 1,\n  "hooks": {\n    "preCompact": [ { "type": "command", "bash": "%s mark" } ],\n    "postToolUse": [ { "type": "command", "bash": "%s copilot" } ]\n  }\n}\n' "$floorHook" "$floorHook"
			;;
		esac
	;;
esac
exit 0
