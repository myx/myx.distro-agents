#!/usr/bin/env bash
## root-session-end.sh -- the SessionEnd and SessionStart (resume) hooks of a root session: a
## *-native client session the team tooling did not spawn (the human-owner's own, an interactive
## native console). A REAL SCRIPT: installed by copying, runs exactly as it stands, nothing
## substituted into it.
##
## A spawned session is closed by its spawn proxy, which writes the end into its spawn record,
## so nothing is done for one: MDAT_SPAWN_SESSION_ID set, or a spawn record of its id here.
## For a root session, named by the payload session_id:
##   end     SessionEnd: the session's `ended` marker (AgentsSessionMarkerFile) written and its store touched
##           (AgentsToolsGrantsStoreTouch), so its session grants end and every index joining
##           its store rebuilds; then, detached, its open asks marked ended for the main loop
##           (--intern-op-pending-reply-collect --mark-ended) and its transcript, where it has
##           one, given its END line (AgentsTranscriptSpawnEnd).
##   resume  SessionStart, source resume: a resume keeps the id, so the marker goes and the
##           store is touched again.
## AgentsToolsGrantsSessionEnded reads the marker. Never blocks or fails the client: always
## exit 0, and nothing on stdout, which a SessionStart hook would add to the context.
## The payload is read by builtins; an id carrying anything but letters, digits, - and _ is ignored.

IFS= read -r -d '' hookInput
exec > /dev/null
hookMode="${1:-end}"
[ -z "${MDAT_SPAWN_SESSION_ID:-}" ] || exit 0

## The workspace: MMDAPP, else the one this script is installed in (<workspace>/.claude/hooks).
hookWs="${MMDAPP:-}"
[ -n "$hookWs" ] || hookWs="$( cd -P "${0%/*}/../.." 2>/dev/null && pwd -P )" || hookWs=""
hookWs="${hookWs%/}"
[ -n "$hookWs" ] && [ -d "$hookWs/.local/agents" ] || exit 0

MDLT_ORIGIN="${MDLT_ORIGIN:-$hookWs/.local}"
hookLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
## A failed load leaves hookString undefined, so the next hookString call exits 0: the hook never fails the client.
type hookString > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/client-hooks/AgentsHookPayload.include"

hookString session_id || exit 0
hookSession="$hookValue"
hookBare "$hookSession" || exit 0
type AgentsSessionMarkerFileInto > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionStore.include"
MMDAPP="$hookWs" AgentsSessionRunRecordInto hookRecord "$hookSession" || :
[ -z "$hookRecord" ] || exit 0
MMDAPP="$hookWs" AgentsSessionMarkerFileInto hookEnded "$hookSession" ended || exit 0
hookStore="${hookEnded%/ended}"
hookTouch(){
	if . "$hookLib/grants/AgentsTools.Grants.include" 2> /dev/null ; then
		AgentsToolsGrantsStoreTouch "$hookSession" "$hookWs"
	fi
}

case "$hookMode" in
	resume)
		if hookString source ; then
			[ "$hookValue" = resume ] || exit 0
		fi
		[ -e "$hookStore/ended" ] || exit 0
		rm -f "$hookStore/ended" 2> /dev/null
		hookTouch
		exit 0
	;;
	end) ;;
	*) exit 0 ;;
esac

hookReason="other"
! hookString reason || ! hookBare "$hookValue" || hookReason="$hookValue"
mkdir -p "$hookStore" 2> /dev/null || exit 0
printf 'ended-at: %s\nreason: %s\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "$hookReason" > "$hookStore/ended" 2> /dev/null || exit 0
hookTouch

## The rest reads each open ask once, so it may take a while: detached, in its own process
## group with HUP ignored, so neither the client ending nor its terminal closing stops it.
hookTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
set -m
(
	trap '' HUP INT
	export MMDAPP="$hookWs" MDLT_ORIGIN
	[ ! -x "$hookTools" ] || "$BASH" "$hookTools" --intern-op-pending-reply-collect --session-id "$hookSession" --mark-ended --context SessionEnd
	if . "$hookLib/session/AgentsTools.SessionTranscript.include" && AgentsTranscriptBase "$hookSession" > /dev/null ; then
		type AgentsTranscriptSpawnEnd > /dev/null 2>&1 || . "$hookLib/session/AgentsTools.SessionTranscriptLife.include"
		AgentsTranscriptSpawnEnd "$hookSession" "session-end:$hookReason" -
	fi
) < /dev/null > /dev/null 2>&1 &
exit 0
