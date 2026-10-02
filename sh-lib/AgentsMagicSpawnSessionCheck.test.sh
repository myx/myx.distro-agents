#!/usr/bin/env bash
## Behavioural check on --magic-spawn-session: exactly one of --routine <selector> |
## --routine-default is required; explicit <team-member>... spawns exactly those, the
## first starting the session and every further one joining it by session id; with no
## positional members, the routine's own executors line supplies the roster, and a
## value that is not a plain comma-separated list of existing members ("magic-team"/"*"
## or prose) is refused; an unknown explicit member is refused too. Offline: a fake
## console records what each spawned member receives, a fake curl answers Slack.
## Modelled on AgentsSpawnSessionThreadCheck.test.sh (fake console/curl rig) and
## AgentsHarnessArmGateCheck.test.sh (env -i isolated scenarios, rig tree only).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"

rigTmp="$( mktemp -d -t "AgentsMagicSpawnSessionCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits (AgentsToolsSpawnSandboxFillInput's own
## read-only-by-mode contract) -- restored before any removal, final cleanup included.
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team/templates" \
	"$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigData/board"

cp "$rigHere/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console each spawned member runs: records its own context, keyed by the acting
## member's own name so two members spawned in one call never overwrite each other's
## record. Same fixture shape as AgentsSpawnSessionThreadCheck.test.sh's.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

cp "$rigRealTemplate" "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
## Both .basic.md (the real-member check --address-to's own send validates against)
## and .armed.md (the one --intern-op-spawn-prepare-brief itself requires).
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-a/rig-member-a.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-b/rig-member-b.basic.md"
printf '# rig armed\n' > "$rigSkills/rig-member-a/rig-member-a.armed.md"
printf '# rig armed\n' > "$rigSkills/rig-member-b/rig-member-b.armed.md"
## The default routine: real executors/maintainers, so every scenario that resolves it
## (explicit members included) passes its own contract check.
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
## A routine whose own executors is a single real member -- the no-positional-members roster case.
printf -- '---\nexecutors: rig-member-a\nmaintainers: rig-member-a\n---\n# rig solo routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.solo.routine.md"
## A routine whose own executors is the "any member" shorthand -- refused, not spawned.
printf -- '---\nexecutors: magic-team\nmaintainers: magic-coordinator\n---\n# rig wildcard routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.wildcard.routine.md"
## A routine whose own executors is prose -- refused the same way.
printf -- '---\nexecutors: the coordinator and friends\nmaintainers: magic-coordinator\n---\n# rig prose routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.prose.routine.md"

rigRun(){ ## stdin content, then --magic-spawn-session args...
	local rigStdin="$1" ; shift
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --magic-spawn-session "$@"
		' rig-run-wrapper "$@" <<< "$rigStdin" 2>&1
}

## Polls for a condition up to 10 seconds -- only the async spawned console's own write
## needs this; everything else --magic-spawn-session itself prints is synchronous.
rigWaitFor(){ ## file
	local rigLeft=10
	while [ ! -s "$1" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
	[ -s "$1" ]
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

## Posting succeeds, so a spawn is never also blocked on Slack config.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

echo "-- explicit members: the first starts the session, the second joins it --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-b )"
rigSessionId="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; }' )"
rigAssert "a session id is reported"                     "$( [ -n "$rigSessionId" ] && echo yes || echo no )" yes
rigAssert "the routine is named"                         "$( printf '%s\n' "$rigOut" | grep -c -x -F 'ROUTINE=magic-team.coworking.routine.md' )" 1
rigAssert "both members are named, in order"             "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a rig-member-b' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
rigAssert "member a's own brief names its own duty file"  "$( grep -c -x -F 'read-and-obey: read rig-member-a.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief.rig-member-a" )" 1
rigAssert "member b's own brief names its own duty file"  "$( grep -c -x -F 'read-and-obey: read rig-member-b.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief.rig-member-b" )" 1
rigAssert "both spawns' own tracking records share one session id" \
	"$( LC_ALL=C grep -h -c -x -F "session-id: $rigSessionId" "$rigWs/.local/agents/spawned"/*/*.md 2>/dev/null | LC_ALL=C awk '{s+=$1 ;} END{print s+0 ;}' )" 2
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- no positional members: the routine's own single-member executors supplies the roster --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine solo )"
rigAssert "lands"                                        "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "the executors member is the one spawned"      "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rm -f "$rigTmp/brief.rig-member-a"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- no positional members, executors a comma list with inner whitespace: trimmed per item, no fork --"
printf -- '---\nexecutors: rig-member-a,  rig-member-b\nmaintainers: rig-member-a\n---\n# rig multi-executor routine fixture with inner whitespace\n' \
	> "$rigSkills/rig-member-a/rig-member-a.multi.routine.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine multi )"
rigAssert "lands"                                        "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "both executors are the roster, trimmed"       "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a rig-member-b' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
rm -f "$rigTmp/brief.rig-member-a" "$rigTmp/brief.rig-member-b"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- executors is the \"any member\" shorthand: refused, nothing spawned --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine wildcard )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'is not a plain comma-separated list of existing members' )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0

echo "-- executors is prose: refused the same way --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine prose )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'is not a plain comma-separated list of existing members' )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0

echo "-- an explicit, unknown member: refused --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-no-such )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'no such team member' )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0

echo "-- both --routine and --routine-default: refused --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --routine solo rig-member-a )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'use only one of --routine' )" 1

echo "-- neither --routine nor --routine-default: refused --"
rigOut="$( rigRun "RIG-TASK-TEXT" rig-member-a )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'exactly one of --routine' )" 1

echo "-- --routine with no value: refused with the one shared wording --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'routine requires <selector>' )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0

echo "-- --routine-default, more than one default-for-session-kind: coworking routine --"
printf -- '---\nexecutors: rig-member-a\nmaintainers: rig-member-a\ndefault-for-session-kind: coworking\n---\n# rig second coworking routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.coworking.routine.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default )"
rigAssert "is refused"                                   "$( printf '%s\n' "$rigOut" | grep -c 'default-for-session-kind: coworking: 2 routine file' )" 1
rigAssert "never falls through to the resolver's own ambiguous-match wording" \
	"$( printf '%s\n' "$rigOut" | grep -c 'matches more than one routine file' )" 0
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0
rm -f "$rigSkills/rig-member-a/rig-member-a.coworking.routine.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MAGIC SPAWN SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MAGIC_SPAWN_SESSION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
