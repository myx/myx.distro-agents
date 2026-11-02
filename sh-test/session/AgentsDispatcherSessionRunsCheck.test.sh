#!/usr/bin/env bash
## Behavioural check on `DistroAgentsDispatcher.fn.sh --list-session-runs` (S5.6's neighbour defect,
## found on MDV at 21:01Z): the operation runs and prints the runs this session may see.
## Held, over a rig workspace with four sessions and their runs:
##   1. The call runs at all: exit 0, and no "command not found" on its error stream.
##   2. It prints the caller's own session and its runs.
##   3. It prints a session of its own run tree (a sub-session).
##   4. It prints a public coworking session of another member.
##   5. It never prints another member's private session, nor any of that session's runs.
##   6. A call from no member's session is refused, rc 1, and prints no rows.
## Red before the defect is fixed: the arm at sh-scripts/DistroAgentsDispatcher.fn.sh:132 calls
## `AgentsToolsDispatcherListRuns`, which no file defines, so the call dies at 127 with
## "AgentsToolsDispatcherListRuns: command not found" and prints no row. The real body is
## `AgentsToolsThisSessionRuns` (sh-lib/session/AgentsTools.ThisSession.include:804).
## Offline: the workspace, its spawn records and its skills folder are this rig's own temp tree;
## nothing opens a socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigDispatcher" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigDispatcher"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDispatcherSessionRunsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigTmp/home" \
	"$rigSkills/rig-member" "$rigSkills/rig-other"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nmaintainers: rig\n---\nrig member identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf -- '---\nmaintainers: rig\n---\nother member identity\n' > "$rigSkills/rig-other/rig-other.basic.md"
## A coworking routine nothing runs a session of: the kind a session is read as comes from its runs'
## routine file, so the public session below records one, and this folder is where it resolves.
printf -- '---\ntype: routine\nrequires-session-kind: coworking\nexecutors: rig-other\nmaintainers: rig-other\n---\n# Steps\n' \
	> "$rigSkills/rig-other/rig-other.coworking.routine.md"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

## One spawn record, as a launcher writes it: no process runs as any of these runs, which is what an
## ended run's record still says until a closer closes it.
rigRec(){ ## session id, spawn id, parent spawn id, owner, status, extra header lines
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: %s\nstarted-at: 2026-11-02 08:00 +0000\n' \
			"$1" "$2" "$3" "$2" "$rigHost" "$4" "$5"
		[ -z "${6:-}" ] || printf '%s\n' "$6"
		printf -- '---\n\n# rig spawn session: %s\n' "$2"
	} > "$rigWs/.local/agents/spawned/$1/$2.spawn.md"
}
rigRec rig-own rig-own-run none rig-member spawn-started ''
rigRec rig-sub rig-sub-run rig-own-run rig-member spawn-started ''
rigRec rig-other-private rig-other-private-run none rig-other spawn-started ''
rigRec rig-other-public rig-other-public-run none rig-other spawn-started 'routine: rig-other.coworking.routine.md'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call from the rig workspace, as the member named: its stdout, stderr and status kept apart.
rigCall(){ ## result name, member (empty for none), session (empty for none)
	local rigName="$1" rigAs="${2:-}" rigSession="${3:-}"
	(
		cd "$rigWs" || exit 1
		env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_WORKSPACE_MODE=team-rig \
			MDAT_SPAWN_AGENT="$rigAs" MDAT_SESSION_ID="$rigSession" \
			bash "$rigDispatcher" --list-session-runs
	) > "$rigTmp/$rigName.out" 2> "$rigTmp/$rigName.err" < /dev/null
	printf '%s' "$?" > "$rigTmp/$rigName.rc"
}
## The session ids its stdout names, one per line, in the order printed: the `session` rows' second
## field, and the `run` rows' second field, so a session printed only through a run row is still seen.
rigSessions(){ LC_ALL=C awk -F'\t' '$1 == "session" || $1 == "run" { print $2 }' "$1" 2> /dev/null | LC_ALL=C sort -u ; }
rigRuns(){ LC_ALL=C awk -F'\t' '$1 == "run" { print $3 }' "$1" 2> /dev/null | LC_ALL=C sort -u ; }
rigOutcome(){ cat "$rigTmp/$1.rc" ; }
rigRowCount(){ LC_ALL=C grep -c -E '^(session|run)	' "$1" 2> /dev/null || : ; }

echo "-- 1. the call runs at all --"
rigCall own rig-member rig-own
rigAssert "the call exits 0" "$( rigOutcome own )" 0
rigAssert "and its error stream does not say the function is missing" \
	"$( LC_ALL=C grep -c -F 'AgentsToolsDispatcherListRuns: command not found' "$rigTmp/own.err" )" 0
rigAssert "control: the call printed some row" "$( [ "$( rigRowCount "$rigTmp/own.out" )" -gt 0 ] && printf printed || printf none )" printed

echo "-- 2. its own session and its runs are printed --"
rigAssert "the caller's own session is printed" "$( rigSessions "$rigTmp/own.out" | LC_ALL=C grep -c -x -F 'rig-own' )" 1
rigAssert "and its own run" "$( rigRuns "$rigTmp/own.out" | LC_ALL=C grep -c -x -F 'rig-own-run' )" 1

echo "-- 3. a session of its own run tree is printed --"
rigAssert "the sub-session is printed" "$( rigSessions "$rigTmp/own.out" | LC_ALL=C grep -c -x -F 'rig-sub' )" 1

echo "-- 4. a public coworking session of another member is printed --"
rigAssert "the coworking session of the other member is printed" "$( rigSessions "$rigTmp/own.out" | LC_ALL=C grep -c -x -F 'rig-other-public' )" 1

echo "-- 5. another member's private session is never printed --"
rigAssert "the other member's private session is not printed" "$( rigSessions "$rigTmp/own.out" | LC_ALL=C grep -c -x -F 'rig-other-private' )" 0
rigAssert "and neither is a run of it" "$( LC_ALL=C awk -F'\t' '$1 == "run" && $3 == "rig-other-private-run" { n++ } END { print n + 0 }' "$rigTmp/own.out" )" 0
rigCall other rig-other rig-other-private
rigAssert "control: the other member does see its own private session" "$( rigSessions "$rigTmp/other.out" | LC_ALL=C grep -c -x -F 'rig-other-private' )" 1

echo "-- 6. a call from no member's session is refused --"
rigCall anon '' ''
rigAssert "the call from no session is refused" "$( rigOutcome anon )" 1
rigAssert "and prints no row" "$( rigRowCount "$rigTmp/anon.out" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ DISPATCHER_SESSION_RUNS CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'DISPATCHER_SESSION_RUNS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
