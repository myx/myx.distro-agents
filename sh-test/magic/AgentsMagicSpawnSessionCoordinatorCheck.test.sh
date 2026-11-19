#!/usr/bin/env bash
## Behavioural check on --spawn-session's coordinator rule: a coworking session always holds a magic-coordinator instance
## as its executor, seated first, so it starts the session and the given member joins it, whoever spawns it. A join into
## a session adds none, and a standalone routine gets none. Any other member's session is refused: the op is
## magic-coordinator's only, the console passes. Offline: same fake console/curl rig as AgentsMagicSpawnSessionCheck.test.sh.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"

## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMagicSpawnSessionCoordinatorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" \
	"$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigSkills/magic-coordinator" "$rigData/board"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "%s %s\\n" "$MDAT_SPAWN_AGENT" "${MDAT_SESSION_ID:-}" >> "$RIG_SCENARIO/started"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

for rigMember in rig-member-a rig-member-b magic-coordinator ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
## A coworking routine run by any member -- the brainstorm/discuss shape -- with the old `session: coworking` kept
## beside the new key, so a spawner that still reads it to add the coordinator is caught.
printf -- '---\nexecutors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\nsession: coworking\n---\n# rig coworking-like routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.rigcowork.routine.md"
## The same, a standalone one.
printf -- '---\nexecutors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig plain routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.rigplain.routine.md"

rigRun(){ ## spawner member (may be empty), stdin content, then --spawn-session args...
	local rigSpawner="$1" rigStdin="$2" ; shift 2
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_SPAWNER="$rigSpawner" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ -z "$RIG_SPAWNER" ] || export MDAT_SPAWN_AGENT="$RIG_SPAWNER"
			cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session "$@"
		' rig-run-wrapper "$@" <<< "$rigStdin" 2>&1
}

rigWaitFor(){ ## file
	local rigLeft=10
	while [ ! -s "$1" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
	[ -s "$1" ]
}

rigReset(){
	rm -f "$rigTmp"/brief.* "$rigTmp/started"
	chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
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

printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- spawned by another member's session: refused, the op is magic-coordinator's only --"
rigOut="$( rigRun rig-member-b "RIG-TASK-TEXT" --routine rigcowork rig-member-a )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c "this session acts as rig-member-b, and spawn-session is magic-coordinator's only" )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):$( ls "$rigWs/.local/agents/spawned" 2>/dev/null | wc -l | tr -d ' ' )" "0:0"
rigReset

echo "-- coworking routine, spawned from the console with one member: magic-coordinator seated first, one session --"
rigOut="$( rigRun "" "RIG-TASK-TEXT" --routine rigcowork rig-member-a )"
rigAssert "lands as one session"                         "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "the coordinator is seated first, then the member" "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=magic-coordinator rig-member-a' )" 1
rigWaitFor "$rigTmp/brief.magic-coordinator" || rigRefuse "magic-coordinator's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "both briefs name the routine"                 "$( grep -c 'magic-team.rigcowork.routine.md' "$rigTmp/brief.magic-coordinator" | awk '{ print ( $1 > 0 ) ? "yes" : "no" ; }' ):$( grep -c 'magic-team.rigcowork.routine.md' "$rigTmp/brief.rig-member-a" | awk '{ print ( $1 > 0 ) ? "yes" : "no" ; }' )" "yes:yes"
rigReset

echo "-- coworking routine, spawned by magic-coordinator itself: an instance of its own is seated in the session --"
rigOut="$( rigRun magic-coordinator "RIG-TASK-TEXT" --routine rigcowork rig-member-a )"
rigAssert "lands as one session"                         "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "the coordinator is seated first, then the member" "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=magic-coordinator rig-member-a' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rigJoinId="$( printf '%s\n' "$rigOut" | sed -n 's/^SESSION_ID=//p' | head -1 )"
rigOut="$( rigRun magic-coordinator "RIG-TASK-TEXT" --routine rigcowork --join-session "$rigJoinId" rig-member-b )"
rigAssert "a join into that session adds no second coordinator" "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-b' )" 1
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigReset

echo "-- coworking routine, two members partitioned into one session each: every child seats its own magic-coordinator --"
rigOut="$( rigRun "" "RIG-TASK-TEXT" --routine rigcowork rig-member-a rig-member-b )"
rigAssert "partitioned into two children"                "$( printf '%s\n' "$rigOut" | sed -n 's/^CHILDREN=//p' | wc -w | tr -d ' ' )" 2
rigLeft=10 ; while [ "$( grep -c . "$rigTmp/started" 2> /dev/null )" -lt 4 ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "each member and one coordinator per child started" "$( grep -c '^rig-member-a ' "$rigTmp/started" ):$( grep -c '^rig-member-b ' "$rigTmp/started" ):$( grep -c '^magic-coordinator ' "$rigTmp/started" )" "1:1:2"
rigAssert "each coordinator sits in a child of its own"  "$( awk '$1 == "magic-coordinator" { print $2 }' "$rigTmp/started" | sort -u | grep -c . )" 2
rigReset

echo "-- standalone routine, spawned from the console: not added --"
rigOut="$( rigRun "" "RIG-TASK-TEXT" --routine rigplain rig-member-a )"
rigAssert "lands"                                        "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "only the given member is spawned"             "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a' )" 1
rigAssert "no added line"                                "$( printf '%s\n' "$rigOut" | grep -c 'added magic-coordinator' )" 0
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rigReset

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MAGIC SPAWN SESSION COORDINATOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MAGIC_SPAWN_SESSION_COORDINATOR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
