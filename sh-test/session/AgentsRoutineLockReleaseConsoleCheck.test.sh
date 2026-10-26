#!/usr/bin/env bash
## Behavioural check on --intern-op-routine-lock-release (F6.2): the console's release of a lock whose holder has no
## record. The operation reads the document's state and session-id, refuses a document already finished or holding no
## session-id, scans the spawn records for one that still names the holder, refuses where one exists, and gives the
## lock back where none does.
## Held:
##   1. a lock note held by a session-id, with no spawn record naming it: released, the note is -finished
##   2. the same note, with a spawn record naming the holder: refused, the note stays -running
##   3. a note already finished: refused
##   4. a note holding no session-id: refused
##   5. a reason given is carried into the receipt
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineLockReleaseConsoleCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigInbox="$rigData/inboxes/magic-coordinator/incoming"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-coordinator" "$rigData/board" "$rigInbox"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigLock="note-rigrelease.md"
rigLockValue="inbox:magic-coordinator:$rigLock"
rigSession="rig-release-session"
rigNote(){ ## state, session-id (empty where none)
	{
		printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: %s\n' "$1"
		[ -z "${2:-}" ] || printf 'session-id: %s\n' "$2"
		printf -- '---\n\nThe state of a rig routine.\n'
	} > "$rigInbox/$rigLock"
}
rigField(){ ## field
	LC_ALL=C awk -v want="$1: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$rigInbox/$rigLock" 2> /dev/null
}
rigRecord(){ ## session-id, routine-lock value
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nroutine-lock: %s\n---\n' "$1" "$2" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigRelease(){ ## result name, value, reason (optional)
	local releaseRc=0 releaseName="$1" releaseValue="$2" releaseReason="${3:-}"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-routine-lock-release "$@"
		' rig-release "$releaseValue" ${releaseReason:+"$releaseReason"} > "$rigTmp/$releaseName.out" 2>&1 || releaseRc=$?
	printf '%s' "$releaseRc" > "$rigTmp/$releaseName.rc"
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- 1. a held lock with no spawn record naming it: released --"
rigNote "rigrelease-running" "$rigSession"
rigRelease no-record "$rigLockValue"
rigAssert "no record: exit 0, the note is rigrelease-finished" "$( cat "$rigTmp/no-record.rc" ):$( rigField state )" "0:rigrelease-finished"
rigReceipt="$( rigField last-receipt )"
rigAssert "the receipt names the console release" "$( [ "${rigReceipt#released by the console: the holder has no record}" != "$rigReceipt" ] && echo yes || echo no )" "yes"

echo "-- 2. the holder still has a record: refused --"
rigNote "rigrelease-running" "$rigSession"
rigRecord "$rigSession" "$rigLockValue"
rigRelease has-record "$rigLockValue"
rigAssert "holder has a record: exit non-zero, the note stays rigrelease-running" "$( cat "$rigTmp/has-record.rc" ):$( rigField state )" "1:rigrelease-running"

echo "-- 3. a note already finished: refused --"
rigNote "rigrelease-finished" "$rigSession"
rm -rf "$rigWs/.local/agents/spawned/$rigSession"
rigRelease finished "$rigLockValue"
rigAssert "already finished: exit non-zero, the note stays rigrelease-finished" "$( cat "$rigTmp/finished.rc" ):$( rigField state )" "1:rigrelease-finished"

echo "-- 4. a note holding no session-id: refused --"
rigNote "rigrelease-running"
rigRelease no-session "$rigLockValue"
rigAssert "no session-id: exit non-zero, the note stays rigrelease-running" "$( cat "$rigTmp/no-session.rc" ):$( rigField state )" "1:rigrelease-running"

echo "-- 5. a reason is carried into the receipt --"
rigNote "rigrelease-running" "$rigSession"
rigRelease reason "$rigLockValue" "manual-override"
rigReceipt="$( rigField last-receipt )"
rigAssert "with a reason: released, the receipt carries it" "$( cat "$rigTmp/reason.rc" ):$( [ "${rigReceipt#released by the console: the holder has no record (manual-override)}" != "$rigReceipt" ] && echo named || echo none )" "0:named"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE LOCK RELEASE CONSOLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_LOCK_RELEASE_CONSOLE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
