#!/usr/bin/env bash
## Behavioural check on --spawn-session: exactly one of --routine <selector> |
## --routine-default is required; explicit <team-member>... spawns exactly those, the
## first starting the session and every further one joining it by session id; with no
## positional members, the routine's own executors line supplies the roster, and a
## value that is not a plain comma-separated list of existing members ("magic-team"/"*"
## or prose) is refused; an unknown explicit member is refused too, and every name is asked
## before the first member is started, so a call with one wrong name starts nobody. Two members whose
## spawns fall inside one second each get a dispatch item and a receipt of their own.
## Offline: a fake console records what each spawned member receives, a fake curl
## answers Slack.
## Modelled on AgentsSpawnSessionThreadCheck.test.sh (fake console/curl rig) and
## AgentsHarnessArmGateCheck.test.sh (env -i MDAT_WORKSPACE_MODE=team-rig isolated scenarios, rig tree only).
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
rigTmp="$( rigTempDir AgentsMagicSpawnSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits (AgentsToolsSpawnSandboxFillInput's own
## read-only-by-mode contract) -- restored before any removal, final cleanup included.
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" \
	"$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigData/board"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console each spawned member runs: records its own context, keyed by the acting
## member's own name so two members spawned in one call never overwrite each other's
## record. Same fixture shape as AgentsSpawnSessionThreadCheck.test.sh's.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'## It hands back, so the proxy never retries it and overwrites the brief it recorded.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## Both .basic.md (the real-member check --address-to's own send validates against)
## and .armed.md (the one --intern-op-spawn-prepare-brief itself requires).
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-a/rig-member-a.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-b/rig-member-b.basic.md"
printf '# rig armed\n' > "$rigSkills/rig-member-a/rig-member-a.armed.md"
printf '# rig armed\n' > "$rigSkills/rig-member-b/rig-member-b.armed.md"
## The default routine: real executors/maintainers, so every scenario that resolves it
## (explicit members included) passes its own contract check.
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
## A routine whose own executors is a single real member -- the no-positional-members roster case.
printf -- '---\nexecutors: rig-member-a\nmaintainers: rig-member-a\nrequires-session-kind: standalone\n---\n# rig solo routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.solo.routine.md"
## A routine whose own executors is the "any member" shorthand -- refused, not spawned.
printf -- '---\nexecutors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig wildcard routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.wildcard.routine.md"
## A routine whose own executors is prose -- refused the same way.
printf -- '---\nexecutors: the coordinator and friends\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig prose routine fixture\n' \
	> "$rigSkills/rig-member-a/rig-member-a.prose.routine.md"

rigRun(){ ## stdin content, then --spawn-session args... -- a last word RIG_CALLER_ENV runs it as magic-coordinator in session rig-caller-session
	local rigStdin="$1" rigCaller=() ; shift
	if [ "${!#}" = RIG_CALLER_ENV ] ; then
		rigCaller=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SESSION_ID=rig-caller-session )
		set -- "${@:1:$(( $# - 1 ))}"
	fi
	env -i ${rigCaller[@]+"${rigCaller[@]}"} MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session "$@"
		' rig-run-wrapper "$@" <<< "$rigStdin" 2>&1
}

## Polls for a condition up to 10 seconds -- only the async spawned console's own write
## needs this; everything else --spawn-session itself prints is synchronous.
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

echo "-- explicit members: one session each, under one agent-less parent --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-b )"
rigSessionId="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; }' )"
rigAssert "a session id is reported"                     "$( [ -n "$rigSessionId" ] && echo yes || echo no )" yes
rigAssert "the routine is named"                         "$( printf '%s\n' "$rigOut" | grep -c -x -F 'ROUTINE=magic-team.coworking.routine.md' )" 1
rigAssert "both members are named, in order"             "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a rig-member-b' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
rigAssert "member a's own brief names its own duty file"  "$( grep -c -x -F 'read-and-obey: read rig-member-a.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief.rig-member-a" )" 1
rigAssert "member b's own brief names its own duty file"  "$( grep -c -x -F 'read-and-obey: read rig-member-b.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/brief.rig-member-b" )" 1
rigAssert "member a's own brief names the armed.md sections" "$( grep -c -x -F 'Read these two sections of magic-team/magic-team.armed.md, the same way, with section and not the whole file: {name: magic-team, file: magic-team.armed.md, section: Nothing stops on its own: log, escalate, resolve|Every message is addressed, tagged, and sent on a real channel}' "$rigTmp/brief.rig-member-a" )" 1
rigAssert "member b's own brief names the armed.md sections" "$( grep -c -x -F 'Read these two sections of magic-team/magic-team.armed.md, the same way, with section and not the whole file: {name: magic-team, file: magic-team.armed.md, section: Nothing stops on its own: log, escalate, resolve|Every message is addressed, tagged, and sent on a real channel}' "$rigTmp/brief.rig-member-b" )" 1
rigAssert "member a's own brief ends its block with the handback line" "$( grep -c -x -F 'When done, hand back; then Wait until dismissed.' "$rigTmp/brief.rig-member-a" )" 1
rigAssert "member b's own brief ends its block with the handback line" "$( grep -c -x -F 'When done, hand back; then Wait until dismissed.' "$rigTmp/brief.rig-member-b" )" 1
rigAssert "both spawns name the agent-less parent as their parent session" \
	"$( LC_ALL=C grep -l -x -F "parent-session-id: $rigSessionId" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null | LC_ALL=C grep -c . )" 2
rigAssert "and each is a session of its own, none the parent's" \
	"$( LC_ALL=C sed -n 's/^session-id: //p' $( LC_ALL=C grep -l -x -F "parent-session-id: $rigSessionId" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null ) | LC_ALL=C grep -v -x -F "$rigSessionId" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 2
rigAssert "a caller with no member: both children report to the person at the console" \
	"$( LC_ALL=C grep -l '^reports-to: user-' $( LC_ALL=C grep -l -x -F "parent-session-id: $rigSessionId" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null ) 2>/dev/null | LC_ALL=C grep -c . )" 2
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- the agent-less parent owns the run as its caller: the children report to the caller, in the caller's thread --"
rm -f "$rigTmp/brief.rig-member-a" "$rigTmp/brief.rig-member-b"
mkdir -p "$rigWs/.local/agents/sessions/rig-caller-session" "$rigSkills/magic-coordinator"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'CRIG00001:1700000000.000500\n' > "$rigWs/.local/agents/sessions/rig-caller-session/session.thread"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-b RIG_CALLER_ENV )"
rigSessionId="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; }' )"
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
rigAssert "each child reports to the caller's session and member" \
	"$( LC_ALL=C grep -l -x -F 'reports-to: rig-caller-session:magic-coordinator' $( LC_ALL=C grep -l -x -F "parent-session-id: $rigSessionId" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null ) 2>/dev/null | LC_ALL=C grep -c . )" 2
rigAssert "the parent's thread is the caller's, so a child's session-parent is that thread" \
	"$( cat "$rigWs/.local/agents/sessions/$rigSessionId/session.thread" 2>/dev/null ):$( LC_ALL=C grep -l -x -F 'parent-thread: CRIG00001:1700000000.000500' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null | LC_ALL=C grep -c . )" "CRIG00001:1700000000.000500:2"
rigParentRecord="$rigWs/.local/agents/spawned/$rigSessionId/$rigSessionId.spawn.md"
rigLeft=10 ; while [ ! -s "$rigParentRecord" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the parent's own record: the caller is its owner, and it reports where the caller is" \
	"$( LC_ALL=C grep -c -x -e 'owner: magic-coordinator' -e 'reports-to: rig-caller-session:magic-coordinator' -e 'agent-less: true' "$rigParentRecord" 2>/dev/null )" 3
rigAssert "it names its children, its watcher's pid and its host, and shows as agent-less in the rosters" \
	"$( LC_ALL=C grep -c -x -F "children: $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^CHILDREN=//p' )" "$rigParentRecord" ) $( LC_ALL=C grep -c -E '^run-process: [0-9]+ ' "$rigParentRecord" ) $( LC_ALL=C grep -c -x -F "host: $( hostname -s 2>/dev/null || echo unknown )" "$rigParentRecord" ) $( LC_ALL=C grep -c -x -F 'session-comment: agent-less parent of magic-team.coworking.routine.md' "$rigParentRecord" )" "1 1 1 1"
rigLeft=30 ; while LC_ALL=C grep -q -x -F 'status: spawn-started' "$rigParentRecord" 2>/dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
## A notice may be collected for some seconds before it is posted.
rigLeft=20 ; while ! LC_ALL=C grep -q -F 'agent-less parent: all spawned sessions are done' "$rigTmp/bodies" 2>/dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the watcher closes it when the last child closes, and its line in the caller's thread names each child and its outcome" \
	"$( LC_ALL=C sed -n 's/^status: //p' "$rigParentRecord" ) $( for rigChild in $( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^CHILDREN=//p' ) ; do LC_ALL=C grep -c -F "$rigChild rig-member-" "$rigTmp/bodies" 2>/dev/null ; done | LC_ALL=C tr '\n' ' ' )$( LC_ALL=C grep -c -F 'agent-less parent: all spawned sessions are done (succeeded): ' "$rigTmp/bodies" 2>/dev/null )" "spawn-succeeded 1 1 1"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions/rig-caller-session"

echo "-- a start that fails partway: the parent watches the children already started, and the error names them --"
rm -f "$rigTmp/brief.rig-member-a"
mkdir -p "$rigSkills/rig-member-c" && printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-c/rig-member-c.basic.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-c )" ; rigRc=$?
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigParentRecord="$( LC_ALL=C grep -l -x -F 'agent-less: true' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null | head -1 )"
rigChild="$( LC_ALL=C sed -n 's/^children: //p' "$rigParentRecord" 2>/dev/null )"
rigAssert "the call fails, its parent record names the one child started, and the error names it too" \
	"$rigRc $( printf '%s\n' "$rigChild" | LC_ALL=C awk '{ print NF }' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- "watches the children already started, and closes over them: $rigChild" ) $( LC_ALL=C grep -c -E '^run-process: [0-9]+ ' "$rigParentRecord" 2>/dev/null )" "1 1 1 1"
rigLeft=30 ; while LC_ALL=C grep -q -x -F 'status: spawn-started' "$rigParentRecord" 2>/dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "and its watcher closes it over that child" "$( LC_ALL=C sed -n 's/^status: //p' "$rigParentRecord" )" "spawn-succeeded"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigSkills/rig-member-c"

echo "-- an orphaned parent, a caller gone, and the coordinator's thread: read by the functions themselves --"
rigFn(){ ## function and its arguments -- run against the rig workspace, the session includes loaded
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.ReviewFlow.include" ; "$@"' rig "$@" 2> /dev/null
}
rigRecordAt(){ ## spawn id, lines... -- a spawn record of the rig
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	{ printf -- '---\nspawn-id: %s\n' "$1" ; shift ; printf '%s\n' "$@" ; printf -- '---\n\n# rig record\n' ; } > "$rigWs/.local/agents/spawned/${rigRecordFor:-x}/${rigRecordFor:-x}.spawn.md"
}
rigRecordFor=rig-orphan ; rigRecordAt rig-orphan 'session-id: rig-orphan' 'owner: magic-coordinator' 'agent-less: true' 'children: rig-kid-a rig-kid-b' 'session-thread: CRIG00001:1700000000.000700' 'status: spawn-started'
rigRecordFor=rig-kid-a ; rigRecordAt rig-kid-a 'session-id: rig-kid-a' 'owner: rig-member-a' 'status: spawn-succeeded'
rigRecordFor=rig-kid-b ; rigRecordAt rig-kid-b 'session-id: rig-kid-b' 'owner: rig-member-b' 'status: spawn-started'
rigAssert "the agent-less coordinator-owned record is no coordinator thread" "$( rigFn AgentsToolsSpawnParentThread rig-none rig-x ; echo " rc=$?" )" " rc=1"
rigFn AgentsToolsSpawnSessionParentClose "$rigWs/.local/agents/spawned/rig-orphan/rig-orphan.spawn.md" ; rigRc=$?
rigAssert "an orphaned parent is not closed while a child is open" "$rigRc $( LC_ALL=C sed -n 's/^status: //p' "$rigWs/.local/agents/spawned/rig-orphan/rig-orphan.spawn.md" )" "1 spawn-started"
rigRecordFor=rig-kid-b ; rigRecordAt rig-kid-b 'session-id: rig-kid-b' 'owner: rig-member-b' 'status: spawn-failed'
rigFn AgentsToolsSpawnSessionParentClose "$rigWs/.local/agents/spawned/rig-orphan/rig-orphan.spawn.md" ; rigRc=$?
rigAssert "and is closed from its children's outcomes once they have closed, resolved-at stamped" "$rigRc $( LC_ALL=C sed -n 's/^status: //p' "$rigWs/.local/agents/spawned/rig-orphan/rig-orphan.spawn.md" ) $( LC_ALL=C grep -c '^resolved-at: ' "$rigWs/.local/agents/spawned/rig-orphan/rig-orphan.spawn.md" )" "0 spawn-failed 1"
rigRecordFor=rig-gone-caller ; rigRecordAt rig-gone-caller 'session-id: rig-gone-caller' 'owner: magic-coordinator' 'status: spawn-succeeded'
rigRecordFor=rig-kid-c ; rigRecordAt rig-kid-c 'session-id: rig-kid-c' 'owner: rig-member-a' 'reports-to: rig-gone-caller:magic-coordinator' 'status: spawn-started'
rigAssert "a reports-to whose caller no longer runs falls back as the route's own steps do" "$( rigFn AgentsToolsRunRoute "$rigWs/.local/agents/spawned/rig-kid-c/rig-kid-c.spawn.md" )" "human-owner"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- a caller's own <type>-* and <type>-? --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default 'rig-*' )"
rigAssert "rig-* names both members of the type, one session each" "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a rig-member-b' ):$( printf '%s\n' "$rigOut" | grep -c '^CHILDREN=' )" "1:1"
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default 'rig-?' )"
rigAssert "rig-? is a choice the caller makes: refused, nothing started, its candidates listed one a line" "$( printf '%s\n' "$rigOut" | grep -c -F 'rig-? is a choice: name the one member to start' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):$( printf '%s\n' "$rigOut" | grep -c -x -e '  rig-member-a' -e '  rig-member-b' )" "1:0:2"
mkdir -p "$rigSkills/solo-one" && printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/solo-one/solo-one.basic.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default 'solo-?' )"
rigAssert "even with one member of the type: refused, its one candidate listed" "$( printf '%s\n' "$rigOut" | grep -c -F 'solo-? is a choice' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):$( printf '%s\n' "$rigOut" | grep -c -x -e '  solo-one' )" "1:0:1"
rm -rf "$rigSkills/solo-one"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default 'nomember-*' )"
rigAssert "a type with no member is refused, naming the type" "$( printf '%s\n' "$rigOut" | grep -c -F 'names no member of the type nomember' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" "1:0"

echo "-- no positional members: the routine's own single-member executors supplies the roster --"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine solo )"
rigAssert "lands"                                        "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "the executors member is the one spawned"      "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rm -f "$rigTmp/brief.rig-member-a"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- no positional members, executors a comma list with inner whitespace: trimmed per item, no fork --"
printf -- '---\nexecutors: rig-member-a,  rig-member-b\nmaintainers: rig-member-a\nrequires-session-kind: standalone\n---\n# rig multi-executor routine fixture with inner whitespace\n' \
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

echo "-- a good first member and an unknown second one: nobody is started, nothing is left behind --"
## What a start leaves: a console that ran, a sandbox with its record, a board item, a post (the session's thread).
## Counted before and after, once the starts of the sections above have had the time to close.
rigLeft(){ printf '%s %s %s %s' "$( ls "$rigTmp" | grep -c '^brief\.' )" "$( ls "$rigWs/.local/agents/spawned" 2>/dev/null | grep -c . )" "$( find "$rigData/board" -type f 2>/dev/null | grep -c . )" "$( grep -c '^chat.postMessage ' "$rigTmp/calls" 2>/dev/null )" ; }
sleep 6
rigLeftBefore="$( rigLeft )"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-no-such )"
sleep 3
rigAssert "is refused, in one line that names the name that is wrong" "$( printf '%s\n' "$rigOut" | grep -c -x -F 'DistroAgentsDispatcher: spawn-session: ⛔ ERROR: no such team member: rig-member-no-such' ) $( printf '%s\n' "$rigOut" | grep 'ERROR' | grep -c -v -F 'SystemContext.SetInputSpec' )" "1 1"
rigAssert "no session is started"                         "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0
rigAssert "the first member, a good one, is not started either: no console ran, and no record, no item and no thread is left" "$( rigLeft )" "$rigLeftBefore"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default rig-member-a ../rig-member-b )"
sleep 3
rigAssert "nor with a second name that is no bare name: refused, nobody started, nothing left" "$( printf '%s\n' "$rigOut" | grep -c -F 'spawn-session: ❗ ASSERT: <team-member> must be a bare name' ) $( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ) [$( rigLeft )]" "1 0 [$rigLeftBefore]"

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

echo "-- --routine-default, the coworking kind routine held by two members --"
cp "$rigSkills/magic-team/magic-team.coworking.routine.md" "$rigSkills/rig-member-a/magic-team.coworking.routine.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default )"
rigAssert "is refused, as the resolver refuses a name held twice" "$( printf '%s\n' "$rigOut" | grep -c 'matches more than one routine file' )" 1
rigAssert "nothing was spawned"                          "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 0
rm -f "$rigSkills/rig-member-a/magic-team.coworking.routine.md"

echo "-- --description: passed unchanged to every spawn of the call, kept on each spawn's own record --"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
rm -f "$rigTmp/brief.rig-member-a" "$rigTmp/brief.rig-member-b"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --description "rework the vars loader" rig-member-a rig-member-b )"
rigAssert "the session is started"                       "$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" 1
rigAssert "both spawn records keep the description as it was given" \
	"$( LC_ALL=C grep -h -c -x -F 'description: rework the vars loader' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null | LC_ALL=C awk '{ s += $1 ; } END { print s + 0 ; }' )" 2
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --description )"
rigAssert "a description with no text is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c -- '--description requires <text>' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" "1:0"
rigAssert "the syntax line of the operation names it"     "$( rigRun "" --no-such-option 2>&1 | grep -c -F -- '[--description <text>]' )" 1

echo "-- two members of one call, both spawns inside one second: each has a dispatch item and a receipt of its own --"
## The rig's clock, held: the stamp a spawn takes for its names (`date -u +%Y%m%dT%H%M%SZ`)
## reads one second for the whole call, as it does when the second spawn starts within the
## first one's second. Every other question of the time goes to the real date. Both spawns
## are made by the one shell of the call, so its pid is one for both: before each name
## carried its spawn's own id, the second spawn took the first one's item for its own.
rigRealDate="$( command -v date )" || rigRefuse "no date on PATH"
mkdir -p "$rigTmp/held"
printf '%s\n' '#!/usr/bin/env bash' \
	'case "$*" in "-u +%Y%m%dT%H%M%SZ") echo 20300101T000000Z ; exit 0 ;; esac' \
	"exec \"$rigRealDate\" \"\$@\"" > "$rigTmp/held/date"
chmod +x "$rigTmp/held/date"
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned" "$rigData/board"
mkdir -p "$rigData/board"
rm -f "$rigTmp/brief.rig-member-a" "$rigTmp/brief.rig-member-b"
rigOut="$( PATH="$rigTmp/held:$PATH" rigRun "RIG-TASK-TEXT" --routine-default rig-member-a rig-member-b )"
rigAssert "the session is started with both members"    "$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a rig-member-b' )" 1
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
rigWaitFor "$rigTmp/brief.rig-member-b" || rigRefuse "rig-member-b's own console never received a context"
rigItemsOf(){ LC_ALL=C grep -l -x -F "owner: $1" "$rigData"/board/*/dispatch-*.md 2>/dev/null | wc -l | tr -d ' ' ; } ## member -> its dispatch items, in any state
rigRecordValues(){ LC_ALL=C sed -n "s/^$1: //p" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2>/dev/null | LC_ALL=C sort -u ; } ## header -> its values over the spawn records, each once
rigAssert "each member has a dispatch item of its own"   "$( rigItemsOf rig-member-a ):$( rigItemsOf rig-member-b )" 1:1
rigAssert "each spawn record names an item of its own"   "$( rigRecordValues spawns | wc -l | tr -d ' ' )" 2
rigAssert "and a receipt of its own"                     "$( rigRecordValues execution-receipt | wc -l | tr -d ' ' )" 2
## The names keep their form: the date, the word, then the calling shell's pid and the first
## part of the spawn's own id; and an item's name still gives its receipt, as the reader of
## an old output log derives it (AgentsHarnessDispatchReceipt, AgentsUniversalHarness.sh).
rigNamesKept=0
for rigRecord in "$rigWs/.local/agents/spawned"/*/*.spawn.md ; do
	[ -f "$rigRecord" ] || continue
	rigSpawnId="${rigRecord##*/}" ; rigSpawnId="${rigSpawnId%.spawn.md}"
	rigReceipt="$( LC_ALL=C sed -n 's/^execution-receipt: //p' "$rigRecord" | head -1 )"
	rigSpawns="$( LC_ALL=C sed -n 's/^spawns: //p' "$rigRecord" | head -1 )"
	printf '%s\n' "$rigReceipt" | LC_ALL=C grep -q -E "^spawn-proxy-20300101T000000Z-[0-9]+-${rigSpawnId:0:8}\$" || continue
	[ "$rigSpawns" = "dispatch-20300101T000000Z-spawn-proxy-${rigReceipt#spawn-proxy-20300101T000000Z-}" ] || continue
	rigNamesKept=$(( rigNamesKept + 1 ))
done
rigAssert "both names keep their form, and end with the first part of the spawn's own id" "$rigNamesKept" 2
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"

echo "-- participants and likely needs: checked before anything starts, recorded, never started here --"
rm -f "$rigTmp"/brief.*
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --participants 'rig-member-b, rig-*' --likely-permission 'Edit:/rig/proj/**' --likely-permission 'WebFetch:https://rig.example/*' --likely-tool Edit rig-member-a )"
rigPartSession="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^SESSION_ID=//p' | head -1 )"
rigAssert "the session starts with the executor; the participants are printed, each once, in the order given" \
	"$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):$( printf '%s\n' "$rigOut" | grep -c -x -F 'MEMBERS=rig-member-a' ):$( printf '%s\n' "$rigOut" | grep -c -x -F 'PARTICIPANTS=rig-member-b rig-member-a' )" "1:1:1"
rigAssert "the session's record carries the participants and the likely permissions and tools" \
	"$( rigRecordValues participants ) | $( rigRecordValues likely-permissions ) | $( rigRecordValues likely-tools )" "rig-member-b rig-member-a | Edit:/rig/proj/**, WebFetch:https://rig.example/* | Edit"
rigWaitFor "$rigTmp/brief.rig-member-a" || rigRefuse "rig-member-a's own console never received a context"
sleep 2
rigAssert "a participant is not started by the spawner: only the executor's console ran" "$( ls "$rigTmp" | grep -c '^brief\.' )" 1
## The executor's invitation: the session's own read gives who is left, and the Agent call's spawn starts the one invited.
rigInSession(){ ## stdin content, member, session id, script, its arguments... -- a call made from inside that member's run of the session
	local inStdin="$1" inMember="$2" inSession="$3" ; shift 3
	env -i MDAT_SPAWN_AGENT="$inMember" MDAT_SESSION_ID="$inSession" MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; cd "$MMDAPP" && exec bash "$@"' rig-in-session "$@" <<< "$inStdin" 2>&1
}
rigSessionScript="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh"
rigUninvited="$( rigInSession "" rig-member-a "$rigPartSession" "$rigSessionScript" --get-uninvited-participants )"
rigAssert "the executor's read: the participants with no run yet, the executor itself not among them" "$( printf '%s\n' "$rigUninvited" | grep -v -e '^SystemContext' -e '^#' )" "rig-member-b"
rigInvite="$( rigInSession "RIG-INVITE-TEXT" rig-member-a "$rigPartSession" "$rigTool" --intern-op-agent-spawn-proxy rig-member-b --from-stdin --dispatch-doc:create --context Agent --calling-member rig-member-a )"
rigAssert "the invitation joins the session and says nobody is left uninvited" \
	"$( printf '%s\n' "$rigInvite" | grep -c -x -F "SESSION_ID=$rigPartSession" ):$( printf '%s\n' "$rigInvite" | grep -c -x -F 'PARTICIPANTS_UNINVITED=' )" "1:1"
rigWaitFor "$rigTmp/brief.rig-member-b" || :
rigAssert "the participant is started on the invitation, with the executor's text" "$( grep -c -F 'RIG-INVITE-TEXT' "$rigTmp/brief.rig-member-b" 2> /dev/null || echo 0 )" 1
rigAssert "and the read now names nobody" "$( rigInSession "" rig-member-a "$rigPartSession" "$rigSessionScript" --get-uninvited-participants | grep -c -v -e '^SystemContext' -e '^#' )" 0
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --participants none rig-member-a )"
rigAssert "--participants none: the session starts, no participant, and the record says none" \
	"$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):$( printf '%s\n' "$rigOut" | grep -c -x -F 'PARTICIPANTS=' ):$( rigRecordValues participants )" "1:1:none"
rigWaitFor "$rigTmp/brief.rig-member-a" || :
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
mkdir -p "$rigSkills/magic-rig-present" && printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-rig-present/magic-rig-present.basic.md"
printf -- '---\nmaintainers: rig\nattendance: present\n---\nrig identity\n' > "$rigSkills/rig-member-b/rig-member-b.basic.md"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --participants all-present-members rig-member-a )"
rigPresent=" $( printf '%s\n' "$rigOut" | sed -n 's/^PARTICIPANTS=//p' ) "
rigInPresent(){ ## member -- in or out of the participants printed
	case "$rigPresent" in *" $1 "*) printf in ;; *) printf out ;; esac
}
rigAssert "all-present-members: a magic-* member by default, another by its attendance: present, and not one with neither" \
	"$( rigInPresent magic-rig-present ) $( rigInPresent rig-member-b ) $( rigInPresent rig-member-a )" "in in out"
rigWaitFor "$rigTmp/brief.rig-member-a" || :
chmod -R u+w -- "$rigWs/.local/agents/spawned" 2>/dev/null ; rm -rf "$rigWs/.local/agents/spawned"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member-b/rig-member-b.basic.md"
rm -rf "$rigSkills/magic-rig-present"
sleep 3
rigLeftBefore="$( rigLeft )"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --participants 'rig-?' rig-member-a )"
sleep 3
rigAssert "a participant rig-? is a choice: refused, its candidates one a line, nobody started, nothing left" \
	"$( printf '%s\n' "$rigOut" | grep -c -F 'participant rig-? is a choice: name the one member to invite' ):$( printf '%s\n' "$rigOut" | grep -c -x -e '  rig-member-a' -e '  rig-member-b' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' ):[$( rigLeft )]" "1:2:0:[$rigLeftBefore]"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --participants 'rig-member-b, rig-member-no-such' rig-member-a )"
rigAssert "an unknown participant: refused, naming it, nobody started" \
	"$( printf '%s\n' "$rigOut" | grep -c -F 'participants: no such team member: rig-member-no-such' ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" "1:0"
rigOut="$( rigRun "RIG-TASK-TEXT" --routine-default --likely-permission 'no-target' rig-member-a )"
rigAssert "a likely permission that is no <tool>:<target>: refused, nobody started" \
	"$( printf '%s\n' "$rigOut" | grep -c -F "is not <tool>:<target>" ):$( printf '%s\n' "$rigOut" | grep -c '^SESSION_ID=' )" "1:0"
sleep 3
rigAssert "and none of the refusals left anything behind" "$( rigLeft )" "$rigLeftBefore"
rigAssert "the syntax line names the participants and the likely needs" "$( rigRun "" --no-such-option 2>&1 | grep -c -F -- '[--participants <entry>[,<entry>...]|none] [--likely-permission <tool>:<target>]... [--likely-tool <tool>]...' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MAGIC SPAWN SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MAGIC_SPAWN_SESSION: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
