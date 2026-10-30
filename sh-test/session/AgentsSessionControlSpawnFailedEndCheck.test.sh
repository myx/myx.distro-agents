#!/usr/bin/env bash
## AgentsSessionControlSpawnFailedEndCheck -- a load defect found 2026-10-29: three control threads
## outlived their one run by 8 to 17 hours, each run having only ever reached spawn-failed. The thread
## counts a spawn-failed record as open forever, the same as a run truly still being closed, so it never
## reads the session as finished and never ends by itself. AgentsToolsSessionControlJudge must read a
## spawn-failed record as settled, the same as spawn-ended-without-close already is, so the thread ends
## within a minute once that is its only record. A record that is open for a real reason must still hold
## the thread. Builds a real control thread, a detached process of the tooling: offline by construction,
## no Slack, no model, one fake spawn record under this rig's own MMDAPP.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling script is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlSpawnFailedEndCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One session, one spawn-failed record, no live process behind it, under a rig workspace of its own.
## $1: the status to write on the record (spawn-failed, by default, for the real scenario).
rigScenario(){ ## scenario label, record status
	local label="$1" status="$2" rigWs sessId spawnId
	rigWs="$rigTmp/$label" ; sessId="sess-$label" ; spawnId="spawn-$label"
	mkdir -p "$rigWs/.local/agents/spawned/$spawnId" "$rigWs/.local/temp"
	cat > "$rigWs/.local/agents/spawned/$spawnId/$spawnId.spawn.md" <<-EOF
	---
	session-id: $sessId
	spawn-id: $spawnId
	host: $( hostname -s )
	workspace: rig-ws
	owner: magic-developer
	status: $status
	started-at: 2026-10-12 15:25 +0300
	run-process: 999999 Mon_Oct_12_15:28:00_2026
	exit-code: 1
	resolved-at: 2026-10-12 15:28 +0300
	---

	# fake record for AgentsSessionControlSpawnFailedEndCheck
	EOF
	( cd / && env -i HOME="$rigWs/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		"$BASH" "$rigTool" --intern-session-control --run --session-id "$sessId" \
		< /dev/null > "$rigWs/thread.out" 2>&1 & )
	local waited=0 ctrlPid=""
	while [ "$waited" -lt 10 ] ; do
		{ IFS=' ' read -r ctrlPid _ < "$rigWs/.local/agents/sessions/$sessId/control/pid" ; } 2> /dev/null
		[ -n "$ctrlPid" ] && kill -0 "$ctrlPid" 2> /dev/null && break
		ctrlPid="" ; sleep 1 ; waited=$(( waited + 1 ))
	done
	[ -n "$ctrlPid" ] || { printf 'rigScenario %s: the control thread never showed a live pid within %ss\n' "$label" "$waited" >&2 ; printf 'never-started' ; return 0 ; }
	rigProcNote "$ctrlPid"
	waited=0
	while kill -0 "$ctrlPid" 2> /dev/null && [ "$waited" -lt 60 ] ; do
		sleep 1 ; waited=$(( waited + 1 ))
	done
	if kill -0 "$ctrlPid" 2> /dev/null ; then
		rigProcSignal KILL "$ctrlPid"
		printf 'still-running'
	else
		printf 'ended-at-%ss' "$waited"
	fi
}

echo "-- a session whose only record is spawn-failed, with no live process, ends within a minute --"
rigResult="$( rigScenario a spawn-failed )"
case "$rigResult" in ended-at-*) rigResult=ended ;; esac
rigAssert "the thread ends by itself, not left running for someone to kill by hand" "$rigResult" "ended"

echo "-- a session with a genuinely unclosed record, same shape, stays open and is not ended --"
rigResult="$( rigScenario b spawn-ended-prematurely )"
rigAssert "the thread stays up: a real open record is not read as settled" "$rigResult" "still-running"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL SPAWN-FAILED END CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_SPAWN_FAILED_END: OK (%d assertions)\n' "$rigPassCount"
