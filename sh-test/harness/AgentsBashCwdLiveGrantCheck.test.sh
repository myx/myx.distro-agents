#!/usr/bin/env bash
## Behavioural check on the Bash tool's cwd gate taking the LIVE grant decision, not the
## access roots as they stood when the run started (defect of 2026-10-31, human-owner):
## a member holding a directory by a standing write row, or by a session grant that landed
## after the run began, may run a command with that directory as its cwd. The roots alone
## refuse both, which asked a keeper for access it already held.
##   1. a cwd under the run's own roots runs.
##   2. a cwd under a place the member holds by a standing write row runs -- refused before.
##   3. the same, for a row written as a place pattern (`<dir-prefix>*/**`), the shape a
##      keeper's own row takes: no root of its own, so only the live decision can open it.
##   4. a cwd opened by a session grant that landed after the refusal runs -- refused before.
##   5. control: a cwd under none of them is still refused, with a REFUSAL-ID.
## Offline: a shell of this box, no endpoint, no credential and no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigTools" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTools"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBashCwdLiveGrantCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
[ -n "${RIG_KEEP:-}" ] || trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

## The rig's own workspace, member set, team data and HOME, so no live row is read.
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigData/board/running" "$rigData/board/processed" "$rigHome" \
	"$rigSkills/$rigMember" "$rigWs/HOLD" "$rigWs/PATTERN" "$rigWs/OUT" "$rigWs/OTHER" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A own words\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
: > "$rigWs/.local/agents/members.registry"
## HOLD: a standing write row naming the whole folder. PATTERN: the same, written as a place
## pattern, the shape keeper-ae3's own row has -- it is no root, so only the live decision can
## open it. OUT: nothing holds it, so it is the refusal and the session grant.
printf '%s:ws:workspace:Edit(%s/HOLD/**)\n' "$rigMember" "$rigWs" > "$rigWs/.local/agents/permissions.registry"
printf '%s:ws:workspace:Edit(%s/PAT*/**)\n' "$rigMember" "$rigWs" >> "$rigWs/.local/agents/permissions.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The run's own roots: its sandbox only, so HOLD, PATTERN and OUT are outside them.
rigCall(){ ## cwd, out name
	( cd "$rigWs" && printf '%s' "{\"command\":\"echo rig-ran\",\"cwd\":\"$1\"}" \
		| env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigData" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
			bash "$rigHarness" --intern-tool Bash --access-read-root "$rigWs/.local" --access-write-root "$rigWs/.local" ) \
		> "$rigTmp/$2.out" 2> "$rigTmp/$2.err" || :
}
rigVerdict(){ ## out name
	case "$( cat "$rigTmp/$1.out" )" in
		*rig-ran*) printf ran ;;
		*'not in the allowed access-root set'*) printf refused ;;
		*) printf other ;;
	esac
}
rigRefusalId(){ ## out name
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/$1.out" "$rigTmp/$1.err" 2>/dev/null | head -1
}
rigOp(){
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}

echo "-- 1. a cwd under the run's own roots runs --"
rigCall "$rigWs/.local" roots
rigAssert "it runs" "$( rigVerdict roots )" ran

echo "-- 2. a cwd under a place the member holds by a standing write row runs --"
rigCall "$rigWs/HOLD" hold
rigAssert "it runs, not refused" "$( rigVerdict hold )" ran

echo "-- 3. the same for a row written as a place pattern --"
rigRoots(){ ## purpose, root -- 1 when that root is in the set, 0 when not
	env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "'"$rigHere"'/client/AgentsTools.ClientAccessRoots.include" ; AgentsToolsClientAccessMemberRoots "$MMDAPP" "$@"' rig "$rigMember" "$1" 2>/dev/null \
		| LC_ALL=C grep -c -x -F -- "$2" || :
}
rigAssert "control: the whole-folder row is one of the member's roots" "$( rigRoots read "$rigWs/HOLD" )" 1
rigAssert "a row whose wildcard sits in its last segment is no root"   "$( rigRoots read "$rigWs/PATTERN" )" 0
rigCall "$rigWs/PATTERN" pattern
rigAssert "it runs, not refused" "$( rigVerdict pattern )" ran

echo "-- 4. a cwd opened by a session grant that landed after the refusal runs --"
rigCall "$rigWs/OUT" outrefused
rigAssert "refused before any grant, with a REFUSAL-ID" "$( rigVerdict outrefused ):$( [ -n "$( rigRefusalId outrefused )" ] && printf id || printf no-id )" "refused:id"
rigOp --intern-op-permission-grant-open human-owner --session-id rig-session --refusal-id "$( rigRefusalId outrefused )" --kind session
rigAssert "the session grant is opened" "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1 )" session
rigCall "$rigWs/OUT" outgranted
rigAssert "the granted cwd then runs" "$( rigVerdict outgranted )" ran

echo "-- 5. control: a cwd under none of them is still refused --"
rigCall "$rigWs/OTHER" other
rigAssert "refused, with a REFUSAL-ID" "$( rigVerdict other ):$( [ -n "$( rigRefusalId other )" ] && printf id || printf no-id )" "refused:id"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BASH CWD LIVE GRANT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  sh-lib/harness/AgentsHarnessToolsBash.include and sh-lib/harness/AgentsHarnessAccess.include -- never the assertion" >&2
	exit 1
fi
printf 'BASH_CWD_LIVE_GRANT: OK (%d assertions, offline)\n' "$rigPassCount"
