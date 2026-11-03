#!/usr/bin/env bash
## S7.18, the shell half — a kill signals the asked session's own record, and a rebuild cannot stand in front of the signal.
## Run, not read, against the REAL dispatcher: a scratch workspace of this rig's own, in a clean `env -i`, holding one live
## stand-in session and no room to write the session registry.
##
## Held (coordinator's ruling on S7.18, relayed 2026-11-03; audit S7.16 item 9): the kill reads the asked session's own
## record and signals first, and rebuilds the registry only where no record names that id. Today
## `AgentsToolsManagerSessionKill` rebuilds the whole registry before anything else (AgentsTools.ManagerSession.include:640-644),
## so where that rebuild cannot be written the kill refuses and signals nothing — and where the registry is large, the
## rebuild is what an operator waits through.
##
## The check makes the rebuild impossible, which is the same ordering fault without a clock: a kill that signals first ends
## the session anyway, and one that rebuilds first ends nothing. A clock would be green on a fast machine, as measured
## 2026-11-03 (9 and 400 records both killed in 2 seconds), so the order is what is tested here.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionKillOrderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## text, words
	case "${1:-}" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## ---- the rig ----
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigStore="$rigTmp/store"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -x "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/temp" "$rigHome/skills/magic-tester" \
	"$rigStore/board" "$rigStore/audit" "$rigStore/contacts" "$rigStore/inboxes" "$rigStore/vault" \
	|| rigRefuse "the rig could not be made"
: > "$rigWs/.local/MDLT.settings.env"
printf -- '---\nname: magic-tester\n---\nrig identity\n' > "$rigHome/skills/magic-tester/magic-tester.basic.md"

rigSession(){ ## id -- a spawn record, and one live process the registry finds by `--session-id`
	local sessionId="$1" sessionPid
	mkdir -p "$rigWs/.local/agents/spawned/$sessionId" || rigRefuse "the spawn record folder could not be made"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-rig\nowner: magic-tester\nstatus: spawn-started\nstarted-at: %s\nreports-to: magic-coordinator\nsession-comment: %s\n---\n\n# Spawn session: %s\n' \
		"$sessionId" "$sessionId" "$sessionId" "$( hostname -s 2>/dev/null )" "$( date '+%Y-%m-%d %H:%M %z' )" "$sessionId" "$sessionId" \
		> "$rigWs/.local/agents/spawned/$sessionId/$sessionId.spawn.md" || rigRefuse "the spawn record could not be written"
	bash -c 'sleep 600; :' "$sessionId" --session-id "$sessionId" > /dev/null 2>&1 &
	sessionPid=$!
	rigProcNote "$sessionPid"
	rigSessionPid="$sessionPid"
	rigKillPids+=( "$sessionPid" )
	sleep 1
	[ "$( ps -o pid= -p "$sessionPid" 2> /dev/null | tr -d ' ' )" = "$sessionPid" ] || rigRefuse "the stand-in session did not start"
}
rigKillPids=()
rigLiveEnd(){
	local endPid
	for endPid in ${rigKillPids[@]+"${rigKillPids[@]}"} ; do
		rigProcSignal TERM "$endPid" 2> /dev/null || :
		wait "$endPid" 2> /dev/null || :
	done
	chmod u+w "$rigWs/.local/agents" 2> /dev/null || :
}
trap 'rigLiveEnd 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

rigCall(){ ## the operation and its words
	rigOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" LC_ALL=en_US.UTF-8 \
		MDAT_WORKSPACE_MODE=team-rig MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigStore" \
		MDAT_SKILLSET_ROOT="$rigHome/skills" MDAT_BASH=/bin/bash MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" "$@" 2>&1 )"
	rigRc=$?
}

## The known positive first: with the registry writable, the same call ends the same kind of session, so a failure below is
## the ordering and not the rig.
rigSession rig-plain-1
rigCall --manager-session-kill --session-id rig-plain-1
rigAssert "a kill ends a stand-in session where the registry can be rebuilt" \
	"$( [ "$( ps -o pid= -p "$rigSessionPid" 2> /dev/null | tr -d ' ' )" = "$rigSessionPid" ] && printf alive || printf gone )" "gone"

## The case: the asked session's own record is there, and the registry cannot be written at all.
rigSession rig-norebuild-1
chmod a-w "$rigWs/.local/agents" || rigRefuse "the registry folder could not be made read-only"
rigCall --manager-session-kill --session-id rig-norebuild-1
rigAssert "the same kill signals the asked session even where the registry cannot be rebuilt" \
	"$( [ "$( ps -o pid= -p "$rigSessionPid" 2> /dev/null | tr -d ' ' )" = "$rigSessionPid" ] && printf alive || printf gone )" "gone"
rigAssert "and its answer says a run was ended" "$( rigHas "$rigOut" "	ended	" )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION KILL ORDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_KILL_ORDER: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
