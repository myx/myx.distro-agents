#!/usr/bin/env bash
## native-transcript-keep.sh -- the SessionStart, Stop and SessionEnd hooks of a SPAWNED native client session (F10.4): the vendor
## client keeps its own session log, in a format of its own, and says where in every hook payload (`transcript_path`); this keeps
## that log in the sandbox of the spawn, so the sandbox and the session hold the whole log of a native run as they hold a harness
## run's context.jsonl. A REAL SCRIPT: installed by copying, runs exactly as it stands, nothing substituted into it.
## For the session named by the payload `session_id`, and only where it is the spawn this process belongs to
## (MDAT_SPAWN_SESSION_ID, MDAT_SPAWN_SANDBOX_ROOT):
##   start   SessionStart: the pointer is written, <sandbox>/<id>.native.path holding the client's path of its log and
##           <workspace>/.local/agents/sessions/<id>/native-log holding the path of the kept copy, so a run that never reaches
##           an end still says where its log is.
##   keep    Stop (a turn of the client ended): the log is copied to <sandbox>/<id>.native.jsonl.
##   end     SessionEnd: the same copy, the last. It carries its own timeout of 5 s (the client gives SessionEnd hooks 1.5 s in all
##           by default).
## The copy is written beside itself and renamed over, mode 600, and left alone while the log is no longer than the copy (a log
## only grows). A path is taken only when it is absolute, ends in `<id>.jsonl` and holds no `..` or backslash: a payload is the
## client's, but the file it names is read as the user. Best effort by design (the client's session is its own): never blocks or
## fails the client, always exit 0, and nothing on stdout, which a SessionStart hook would add to the context. A session the tooling
## did not spawn, or whose id is not the spawn's, is no business of this hook.
## The payload is read by builtins; an id carrying anything but letters, digits, - and _ is ignored.

IFS= read -r -d '' hookInput
exec > /dev/null
hookMode="${1:-keep}"
[ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] && [ -d "$MDAT_SPAWN_SANDBOX_ROOT" ] || exit 0

## The plain string value of the first "<key>" of the payload, into hookValue; rc 1 when absent.
hookString(){ ## key
	local stringRest="${hookInput#*\"$1\"}"
	hookValue=""
	[ "$stringRest" != "$hookInput" ] || return 1
	while : ; do
		case "$stringRest" in
			' '*|$'\t'*|$'\n'*|$'\r'*|:*) stringRest="${stringRest:1}" ;;
			*) break ;;
		esac
	done
	case "$stringRest" in \"*) stringRest="${stringRest:1}" ;; *) return 1 ;; esac
	hookValue="${stringRest%%\"*}"
	[ "$hookValue" != "$stringRest" ]
}
## Letters, digits, - and _ only, enumerated: a bracket range is collation-dependent.
hookBare(){ ## text
	case "$1" in
		''|.|..|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-]*) return 1 ;;
	esac
	return 0
}

hookString session_id || exit 0
hookId="$hookValue"
hookBare "$hookId" && [ "$hookId" = "$MDAT_SPAWN_SESSION_ID" ] || exit 0
hookString transcript_path || exit 0
hookLog="$hookValue"
case "$hookLog" in /*.jsonl) ;; *) exit 0 ;; esac
case "$hookLog" in *..*|*\\*) exit 0 ;; esac
[ "${hookLog##*/}" = "$hookId.jsonl" ] || exit 0

hookRoot="${MDAT_SPAWN_SANDBOX_ROOT%/}"
hookCopy="$hookRoot/$hookId.native.jsonl"

## The workspace: MMDAPP, else the one this script is installed in (<workspace>/.claude/hooks).
hookWs="${MMDAPP:-}"
[ -n "$hookWs" ] || hookWs="$( cd -P "${0%/*}/../.." 2>/dev/null && pwd -P )" || hookWs=""
hookWs="${hookWs%/}"

case "$hookMode" in
	start)
		printf '%s\n' "$hookLog" > "$hookRoot/$hookId.native.path" 2> /dev/null || :
		if [ -n "$hookWs" ] && [ -d "$hookWs/.local/agents" ] && mkdir -p "$hookWs/.local/agents/sessions/$hookId" 2> /dev/null ; then
			printf '%s\n' "$hookCopy" > "$hookWs/.local/agents/sessions/$hookId/native-log" 2> /dev/null || :
		fi
		exit 0
	;;
	keep|end) ;;
	*) exit 0 ;;
esac

[ -f "$hookLog" ] && [ -r "$hookLog" ] || exit 0
## A log only grows: one no longer than the copy is already kept.
hookSize="$( wc -c < "$hookLog" 2> /dev/null )" || exit 0
hookKept="$( wc -c < "$hookCopy" 2> /dev/null )" || hookKept=""
hookSize="${hookSize//[ ]/}" ; hookKept="${hookKept//[ ]/}"
[ -z "$hookKept" ] || [ "$hookSize" -gt "$hookKept" ] 2> /dev/null || exit 0
hookTemp="$( mktemp "$hookCopy.XXXXXX" 2> /dev/null )" || exit 0
if chmod 600 "$hookTemp" 2> /dev/null && cp -- "$hookLog" "$hookTemp" 2> /dev/null ; then
	mv -f "$hookTemp" "$hookCopy" 2> /dev/null || rm -f "$hookTemp"
else
	rm -f "$hookTemp"
fi
exit 0
