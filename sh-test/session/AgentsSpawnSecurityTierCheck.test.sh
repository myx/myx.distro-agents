#!/usr/bin/env bash
## Behavioural check on what a spawn does with the security tier (stage 3 of the security context tier
## set), run rather than read, against a rig workspace and a rig skillset built here, with a console
## stand-in that records the brief and starts no model, and a Slack-shaped fake curl.
## Held, one case per statement:
##   1. `--security-tier private` is a flag the proxy takes, and the tier it names is on the spawn
##      record's header, so a reader of a record sees it
##   2. the flag stands ahead of everything else
##   3. the routine's own key stands ahead of the workspace setting
##   4. a routine that names no tier inherits its kind routine's, as `requires-session-kind:` is
##   5. the workspace setting decides where no routine names one
##   6. the last branch is `system`, decided and recorded, where nothing names a tier
##   7. the tier lands in the session's own folder, one line, and no other folder of the session store
##   8. a second spawn into the same session never rewrites the tier the session already holds
##   9. a word that is none of the four refuses the spawn, and nothing is launched or recorded
## Red before stage 3: every case fails -- the proxy refuses `--security-tier` as an invalid option, so
## no record carries a tier and no session folder holds one.
## Offline: a fake console, a fake curl, every workspace a folder of the rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this run resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnSecurityTierCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Each proxy a case starts keeps its pid in `$rigTmp/pids`, and what it left running, its children first, is ended with the rig.
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; [ ! -f "$rigTmp/pids" ] || while IFS= read -r rigLeftPid ; do pkill -P "$rigLeftPid" 2> /dev/null ; kill "$rigLeftPid" 2> /dev/null ; done < "$rigTmp/pids" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigHome="$rigTmp/home"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/members" "$rigSkills/magic-team" "$rigHome" "$rigTmp/bin" "$rigScenario" \
	|| rigRefuse "cannot make the rig"
for rigMember in magic-coordinator magic-tester magic-team human-owner rig-member ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember" "$rigSkills/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf -- '---\nname: %s\n---\nrig\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a case could reach a socket"
export RIG_SCENARIO="$rigScenario"
: > "$rigScenario/bodies" ; : > "$rigScenario/calls"
## The console the proxy launches: it records the brief and marks its own launch, and runs no model. The
## proxy greps this file for both markers before it launches anything, so the comment line below is part
## of the stub's contract and not decoration.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured and MDAT_SPAWN_LAUNCH_MARKER stand-ins: record the brief, mark the launch.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'exit 0 ## cli-configured, as a regenerated console carries it' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## The rig's routines. A routine of a kind inherits its kind routine's keys.
rigRoutine(){ ## file name, extra frontmatter block (may be empty)
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n%b---\n# %s\n' "$2" "$1" \
		> "$rigSkills/magic-team/$1"
}
rigScope(){ ## extra settings lines (may be empty)
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n%b' "$1" \
		> "$rigWs/.local/.agents/magic-team.agent.env"
}
printf 'SLACK_USER_TOKEN=rig-user-magic-coordinator\n' > "$rigWs/.local/.agents/magic-coordinator.agent.env"
rigRoutine magic-team.coworking.routine.md ""
rigRoutine magic-team.rig-own.routine.md ""

rigPass=0 ; rigFail=0
rigOutcome(){ ## rc -- refused or accepted, as a word for an assertion
	case "$1" in 0) printf accepted ;; *) printf refused ;; esac
}
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One spawn, its whole output kept, with the caller a bare command line that owns no session unless a
## case gives it one. A spawn joins a session through the caller's own `MDAT_SESSION_ID`, which is how a
## running member joins the session it works in; the proxy has no join flag of its own.rigSpawnOut="" ; rigSpawnRc=0 ; rigCallerSession=""
rigSpawn(){ ## the proxy's own arguments...
	: > "$rigScenario/brief"
	rigSpawnOut="$( ( cd "$rigWs" && sh -c 'echo $$ >> "$1" ; shift ; exec "$@"' sh "$rigTmp/pids" env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigScenario" \
		${rigCallerSession:+MDAT_SESSION_ID="$rigCallerSession" MDAT_SESSION_WORKSPACE="$rigWs"} \
		bash "$rigTool" --intern-op-agent-spawn-proxy rig-member "$@" --dispatch-doc:none --wait --context rig-tier 2>&1 <<< 'RIG-TASK-TEXT' ) )" ; rigSpawnRc=$?
}
rigLastSession(){ ## the session id the last spawn's own output names
	printf '%s\n' "$rigSpawnOut" | LC_ALL=C sed -n 's/^SESSION_ID=//p' | head -1
}
rigHeaderOf(){ ## session, header -- the value the record of that session carries
	LC_ALL=C sed -n "s/^$2: //p" "$rigWs/.local/agents/spawned/$1/$1.spawn.md" 2> /dev/null | head -1
}
rigTierOf(){ ## session -- what the session's own folder records
	cat "$rigWs/.local/agents/sessions/$1/security.tier" 2> /dev/null || :
}

echo "-- 0. control: the rig itself works on the untouched tree --"
## The control the coordinator requires: it passes on the untouched tree, so a case failing beside it
## is the tier's, not a broken rig. It proves the console stand-in is accepted, the task text reaches
## the proxy on stdin, and the same fixture file's frontmatter reads back through the package's own key
## reader -- the three things the four rig defects broke.
rigScope ""
rigRoutine magic-team.rig-ctl.routine.md ""
rigSpawn
rigAssert "the proxy launches a plain spawn: the console stand-in is accepted" \
	"$( printf '%s\n' "$rigSpawnOut" | LC_ALL=C grep -c -E '^LAUNCHED=true|^STATUS=succeeded' )" 2
rigAssert "and the task text the check sends on stdin reached the console's brief" \
	"$( LC_ALL=C grep -c -F 'RIG-TASK-TEXT' "$rigScenario/brief" 2> /dev/null )" 1
rigAssert "the routine fixture's own frontmatter reads back through the package's key reader" \
	"$( ( . "$rigPackage/sh-lib/routine/AgentsTools.RoutineRequirements.include" 2> /dev/null ; AgentsToolsRoutineKeyOwn "$rigSkills/magic-team/magic-team.rig-ctl.routine.md" requires-session-kind ) 2> /dev/null )" \
	coworking

if [ "$rigFail" -ne 0 ] && [ "$rigPass" -lt 3 ] ; then
	echo "⛔ SPAWN SECURITY TIER CHECK BROKEN: the control fails on the untouched tree, so no case beside it means anything" >&2
	exit 1
fi

echo "-- 1. --security-tier is a flag the proxy takes, and the record names it --"
rigScope ""
rigSpawn --security-tier private
rigSpawnSession="$( rigLastSession )"
rigAssert "the proxy accepts --security-tier private" \
	"$( printf '%s\n' "$rigSpawnOut" | LC_ALL=C grep -c -F -- 'invalid option: --security-tier' )" 0
rigAssert "the spawn record's header names the tier chosen" "$( rigHeaderOf "$rigSpawnSession" security-tier )" private

echo "-- 2. the flag stands ahead of everything else --"
rigScope "SECURITY_TIER_DEFAULT=shared\n"
rigRoutine magic-team.rig-own.routine.md "security-tier: system\n"
rigSpawn --routine magic-team.rig-own.routine.md --security-tier private
rigAssert "a flag beats the routine key and the workspace setting" "$( rigHeaderOf "$( rigLastSession )" security-tier )" private

echo "-- 3. the routine's own key stands ahead of the workspace setting --"
rigSpawn --routine magic-team.rig-own.routine.md
rigAssert "the routine's system beats the workspace's shared" "$( rigHeaderOf "$( rigLastSession )" security-tier )" system

echo "-- 4. a routine inherits its kind routine's tier --"
rigRoutine magic-team.coworking.routine.md "security-tier: private\n"
rigRoutine magic-team.rig-own.routine.md ""
rigSpawn --routine magic-team.rig-own.routine.md
rigAssert "a routine silent on the key takes its kind routine's private" "$( rigHeaderOf "$( rigLastSession )" security-tier )" private
rigRoutine magic-team.coworking.routine.md ""

echo "-- 5. the workspace setting decides where no routine names one --"
rigSpawn
rigAssert "the workspace's shared decides" "$( rigHeaderOf "$( rigLastSession )" security-tier )" shared

echo "-- 6. the last branch is system, decided and recorded --"
rigScope ""
rigSpawn
rigAssert "with nothing set the spawn records system" "$( rigHeaderOf "$( rigLastSession )" security-tier )" system

echo "-- 7. the tier lands in the session's own folder, once --"
rigSpawn --security-tier private
rigSortieSession="$( rigLastSession )"
rigAssert "the session's own folder holds the tier its record names" "$( rigTierOf "$rigSortieSession" )" private
rigAssert "as one line" "$( [ -f "$rigWs/.local/agents/sessions/$rigSortieSession/security.tier" ] && LC_ALL=C wc -l < "$rigWs/.local/agents/sessions/$rigSortieSession/security.tier" | LC_ALL=C tr -d ' ' || printf none )" 1
rigAssert "and no record of it stands anywhere outside a session's own folder" \
	"$( [ "$( find "$rigWs/.local" -name 'security.tier' 2> /dev/null | LC_ALL=C grep -c . )" = "$( find "$rigWs/.local" -name 'security.tier' 2> /dev/null | LC_ALL=C grep -c -E '/sessions/[^/]+/security.tier$' )" ] && printf all-in-sessions || printf elsewhere )" all-in-sessions

echo "-- 8. a second spawn into the same session keeps the tier it holds --"
rigSpawn --security-tier private
rigSecondSession="$( rigLastSession )"
rigCallerSession="$rigSecondSession"
rigSpawn --security-tier public
rigCallerSession=""
rigAssert "the second spawn's tier request did not rewrite the session's own tier" "$( rigTierOf "$rigSecondSession" )" private

echo "-- 9. a word that is none of the four refuses the spawn --"
: > "$rigScenario/brief"
rigSpawn --security-tier secret
rigAssert "a fifth word is refused" "$( rigOutcome "$rigSpawnRc" )" refused
rigAssert "nothing reached the console" "[$( [ -s "$rigScenario/brief" ] && printf launched || printf none )]" "[none]"
rigAssert "and no session folder and no spawn record took the word" \
	"$( find "$rigWs/.local/agents" -name 'security.tier' -newer "$rigScenario/brief" 2> /dev/null | LC_ALL=C grep -c . )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SPAWN SECURITY TIER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the spawn proxy's flag, its resolution and the store's write -- never the assertion" >&2
	exit 1
fi
printf 'SPAWN_SECURITY_TIER: OK (%d assertions, offline)\n' "$rigPass"
