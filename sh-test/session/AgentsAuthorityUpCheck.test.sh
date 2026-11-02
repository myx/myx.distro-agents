#!/usr/bin/env bash
## Behavioural check on S27.6: authority over a run whose parent session has ended passes up, to
## that parent's own parent, else to the root coordinator and the owners role. Today `TaskStop` of
## such a run is refused for want of the dead parent's authority, and nobody can end it.
## Red before S27.6: the founder of a live session whose own parent has ended is refused, though
## the ladder gives it the authority the dead parent held.
## Offline: the workspace, its board and its spawn records are this rig's own temp tree. No socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigAuth="$rigPkg/sh-lib/questions/AgentsTools.Authority.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAuth" ] || rigRefuse "the authority include is not at the origin: $rigAuth"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsAuthorityUpCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigWs/.local/.agents" "$rigSpawned" "$rigWs/.local/agents/sessions"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigRecord(){ ## folder, spawn id, session, parent-session-id, status, owner
	mkdir -p "$rigSpawned/$1" "$rigWs/.local/agents/sessions/$3"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nparent-session-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: %s\nstart-context: spawned\n---\n' \
		"$3" "$2" "$4" "$1" "$rigHost" "$6" "$5" > "$rigSpawned/$1/$2.spawn.md"
}
rigAlive(){ ## spawn id
	python3 -I -B -c 'import time; time.sleep(180)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
}
rigHolds(){ ## caller spawn id, holder word, session of the run acted on, caller member, run record
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="${4:-magic-coordinator}" MDAT_SPAWN_SESSION_ID="$1" \
		bash -c '. "$1" ; AgentsToolsAuthorityCaller ; AgentsToolsAuthorityHolds "$2" "$3" "${4:-}" && printf holds || printf refused' \
		rig "$rigAuth" "$2" "$3" "${5:-}" 2>&1
}

echo "-- 1. a founder whose own parent has ended holds what that parent held (S27.6) --"
## The grandparent founded nothing that survives: its record is closed. Its child founded a live
## session, and that child is the run whose authority is asked about.
rigRecord rig-gp rig-gp-$$ rig-sess-gp none spawn-succeeded magic-coordinator
rigRecord rig-parent rig-parent-$$ rig-sess-parent rig-sess-gp spawn-succeeded magic-tester
rigRecord rig-child rig-child-$$ rig-sess-child rig-sess-parent spawn-started magic-developer
rigAlive rig-child-$$
sleep 2
rigAssert "the founder whose parent ended holds it"       "$( rigHolds rig-child-$$ "rig-sess-parent:magic-tester" rig-sess-child )" "holds"

echo "-- 2. a control: with the founder's own parent alive, the ladder is not reached --"
rigRecord rig-parent2 rig-parent2-$$ rig-sess-parent2 rig-sess-gp spawn-started magic-tester
rigAlive rig-parent2-$$
sleep 2
## A member that is neither the coordinator nor in the owners role: where the ladder is not reached,
## it holds nothing, and that is the control that says the ladder is the thing doing the work.
rigAssert "a live parent's own authority is not borrowed"  "$( rigHolds rig-child-$$ "rig-sess-parent2:magic-tester" rig-sess-child keeper-myx "$rigSpawned/rig-child-$$/rig-child-$$.spawn.md" )" "refused"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ AUTHORITY UP CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'AUTHORITY_UP: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
