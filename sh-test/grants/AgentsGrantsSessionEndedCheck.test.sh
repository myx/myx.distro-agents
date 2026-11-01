#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## AgentsGrantsSessionEndedCheck.test.sh -- a session that is still running is never read as ended, whatever its spawn
## record's status line says (S21.4). One stale `status: spawn-failed`, written while the session ran on, makes every
## `session` grant in that store skipped, so a member's approved permission set grants nothing.
##
## Held:
##  1. a record saying `spawn-failed`, with the session's chat written after that record, is NOT ended
##  2. the control: the same record with no later activity IS ended
##  3. the control: a record saying `spawn-started` is not ended, whatever the activity
##
## Offline: a rig store is written under this workspace's scratch, and nothing is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents"
rigGrants="$rigHere/sh-lib/grants/AgentsTools.Grants.include"
[ -f "$rigGrants" ] || { echo "⛔ ERROR: no grants include at $rigGrants" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsGrantsSessionEndedCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigScene(){ ## store root, session id, status, activity after the record (yes|no)
	local sceneRoot="$1" sceneId="$2" sceneStatus="$3" sceneAfter="$4"
	mkdir -p "$sceneRoot/spawned/spawn-0abc" "$sceneRoot/sessions/$sceneId"
	printf -- '---\ntype: spawn\nstatus: %s\n---\n\n# %s\n' "$sceneStatus" "$sceneId" > "$sceneRoot/spawned/spawn-0abc/$sceneId.spawn.md"
	## the session's own chat: written before the record, or after it
	printf '# chat\n' > "$sceneRoot/sessions/$sceneId/session.chat"
	if [ "$sceneAfter" = "yes" ] ; then
		touch -t 209901010000 "$sceneRoot/sessions/$sceneId/session.chat" 2> /dev/null || sleep 1
	fi
}

rigEnded(){ ## store root of one session -- "ended" or "live"
	if MMDAPP="$MMDAPP" bash -c '. "$1" > /dev/null 2>&1 ; AgentsToolsGrantsSessionEnded "$2"' _ "$rigGrants" "$1" > /dev/null 2>&1 ; then
		printf 'ended\n'
	else
		printf 'live\n'
	fi
}

echo "-- 1. a session that ran on after a spawn-failed record is not ended --"
rigScene "$rigTmp/a" sess-stale spawn-failed yes
rigAssert "the stale record does not end a live session" "$( rigEnded "$rigTmp/a/sessions/sess-stale" )" "live"

echo "-- 2. the control: nothing after the record --"
rigScene "$rigTmp/b" sess-dead spawn-failed no
rigAssert "a failed record with no activity after it is ended" "$( rigEnded "$rigTmp/b/sessions/sess-dead" )" "ended"

echo "-- 3. the control: a started record --"
rigScene "$rigTmp/c" sess-started spawn-started no
rigAssert "a started record is never ended" "$( rigEnded "$rigTmp/c/sessions/sess-started" )" "live"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ GRANTS SESSION ENDED CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  fix:  read the session's own activity beside the record's status, as AgentsToolsGrantsSessionEnded does not" >&2
	exit 1
fi
printf 'GRANTS_SESSION_ENDED: OK (%d assertions, offline)\n' "$rigPasses"
