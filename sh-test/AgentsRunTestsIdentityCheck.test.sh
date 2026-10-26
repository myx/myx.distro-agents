#!/usr/bin/env bash
## Behavioural check on what a test is handed of the session its runner was started in (sh-test/AgentsRunTests.sh), run
## rather than read, on a fixture machine built here: a HOME, a workspace, and one copy of a package with the runner
## under test and one tiny test, which writes down the environment it finds. The runner is started the way a member's
## session that a spawn started would start it: holding everything the spawn proxy and its console hand such a session.
## Held: the test finds none of it -- not the spawn's id and its member, not the coworking session and its thread, not
## the conversations it continues, its sandbox, its launch marker, whether its caller waits and how its CLI was started,
## nor a variable of those two families that only this check knows -- so a rig is a session of its own and joins no
## live one; it finds the test-only session id the runner gives it, and its reminders off; and what is no session's
## reaches it as given: the member set and the team data root the tooling's environment hands the tests. The control is
## the same tiny test started with no runner between, where it finds every one of them.
## The live fault this pins: the suite run by a spawned member, and three tests red there that pass from any other
## session. A rig's spawn joined the runner's own coworking session and took its thread, so its handback retry started
## the rig's console once more (AgentsHarnessUnattendedScopeCheck); a rig's question to a member went into that thread
## (AgentsHarnessAskFormsCheck); a rig's harness kept its scratch in that member's sandbox (AgentsCredentialExposureCheck).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsIdentityCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws" ; rigMembers="$rigTmp/members" ; rigData="$rigTmp/data" ; rigLive="$rigTmp/live"
rigTests="$rigWs/.local/temp/rig-scratch-a/source/myx/myx.distro-agents/sh-test"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigMembers/rig-member" "$rigData" "$rigTests"
printf 'rig member\n' > "$rigMembers/rig-member/rig-member.basic.md"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the fixture ----
## The copy: the runner under test, and its tiny test, which writes down every variable of the tooling it finds.
cp "$rigRunner" "$rigTests/AgentsRunTests.sh"
mkdir -p "$rigTests/check-fixtures" && cp "$(dirname "$rigRunner")/check-fixtures"/runner-*.py "$rigTests/check-fixtures"/
cat > "$rigTests/RigEnv.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
env | LC_ALL=C grep -E '^(MDAT_[A-Z_]*|harness[A-Za-z]*|CLAUDE_CODE_SESSION_ID)=' > "$RIG_SHARED/found.$RIG_HOW"
echo "RIG_TINY: OK"
RIGTINY
## What a spawn hands the session it starts (AgentsTools.InternOpAgentSpawnProxy.include, and the console it runs),
## as the calling session holds it, every value this rig's own; and one variable of each family no tooling knows.
rigHanded=( MDAT_SPAWN_SESSION_ID=rig-live-spawn MDAT_SPAWN_AGENT=rig-live-member MDAT_SPAWN_CALLER_WAITS=false
	MDAT_SPAWN_LAUNCH_MARKER="$rigLive/sessions/rig-live-spawn/launch" MDAT_SPAWN_SANDBOX_ROOT="$rigLive/spawned/rig-live-session"
	MDAT_SPAWN_SANDBOX_ROOT_REAL="$rigLive/spawned/rig-live-session" MDAT_SESSION_ID=rig-live-session MDAT_SESSION_THREAD=CRIG00001:1700000000.000100
	MDAT_CONVERSATION_THREADS=CRIG00002:1700000000.000200 MDAT_SESSION_UNATTENDED=true MDAT_SPAWN_RIG_UNKNOWN=rig MDAT_SESSION_RIG_UNKNOWN=rig
	harnessSessionId=rig-live-spawn harnessAgent=rig-live-member CLAUDE_CODE_SESSION_ID=rig-live-client )
rigStart(){ ## how (runner: through the runner under test; direct: the tiny test itself) -- its output in <how>.out, its rc in rigRc
	local startWhat="$rigTests/AgentsRunTests.sh" ; [ "$1" = runner ] || startWhat="$rigTests/RigEnv.test.sh"
	rigRc=0
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigWs/.local/temp/rig-scratch-a/source" MYXROOT="${MYXROOT:-}" \
		MDAT_SKILLSET_ROOT="$rigMembers" MDAT_DATA_ROOT="$rigData" RIG_SHARED="$rigTmp" RIG_HOW="$1" "${rigHanded[@]}" \
		bash "$startWhat" $( [ "$1" != runner ] || printf RigEnv ) ) > "$rigTmp/$1.out" 2>&1 || rigRc=$?
}
rigHandedFound(){ ## how -- the names the test found of what a spawn hands a session, sorted, on one line
	LC_ALL=C sed -n -E 's/^((MDAT_SPAWN_|MDAT_SESSION_)[A-Z_]*|MDAT_CONVERSATION_THREADS|harness[A-Za-z]*)=.*/\1/p' "$rigTmp/found.$1" 2> /dev/null \
		| LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigFound(){ ## how, variable -- what the test found that variable holding
	LC_ALL=C sed -n "s/^$2=//p" "$rigTmp/found.$1" 2> /dev/null
}

echo "-- 1. a test finds nothing of the session its runner was started in --"
rigStart runner
rigAssert "the test is run and passes" "$rigRc $( LC_ALL=C grep -c '^PASS  RigEnv ' "$rigTmp/runner.out" || : )" "0 1"
rigAssert "it finds no variable a spawn hands the session it starts, nor one of those families that no tooling knows" "$( rigHandedFound runner )" ""
rigStart direct
rigAssert "control: started with no runner between, the same test finds every one of them" "$rigRc $( rigHandedFound direct )" \
	"0 MDAT_CONVERSATION_THREADS MDAT_SESSION_ID MDAT_SESSION_RIG_UNKNOWN MDAT_SESSION_THREAD MDAT_SESSION_UNATTENDED MDAT_SPAWN_AGENT MDAT_SPAWN_CALLER_WAITS MDAT_SPAWN_LAUNCH_MARKER MDAT_SPAWN_RIG_UNKNOWN MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SANDBOX_ROOT_REAL MDAT_SPAWN_SESSION_ID harnessAgent harnessSessionId"

echo "-- 2. it is a session of its own, and what is no session's reaches it as given --"
rigAssert "its session id is the test-only one the runner gives it, never its caller's" "$( rigFound runner CLAUDE_CODE_SESSION_ID ) $( rigFound direct CLAUDE_CODE_SESSION_ID )" "rig-run-RigEnv-test-only rig-live-client"
rigAssert "its waits remind no ask" "$( rigFound runner MDAT_WAIT_REMIND )" "off"
rigAssert "the member set and the team data root reach it as the environment gave them" "$( rigFound runner MDAT_SKILLSET_ROOT ) $( rigFound runner MDAT_DATA_ROOT )" "$rigMembers $rigData"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS IDENTITY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_IDENTITY: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
