#!/usr/bin/env bash
## Behavioural check on the tools of a root-harness session (epic S18.3; sketch 3.1: "every tool ban is only a real access check in the tooling, with a real
## redirection or rejection"; sketch 10.5: AgentDispatcherTools "is the coordinator role surface over all of them, owns no state, delegates everything").
## A root-harness session is the one a server instance carries after RootSession operation=mint: its folder holds the mint's token. It can only spawn
## sessions, through AgentDispatcherTools --spawn-run, each call naming a place by --select-workspace <place-name>, resolved by the places API.
## Read off the wire, from a real server's own answers (as AgentsMcpSecondaryToolCheck does), one server life: initialize, tools/list, a mint, then the calls.
## Held:
##   1. AgentDispatcherTools is in the tool list, once, with the operation shape of the other secondary tools;
##   2. in a root-harness session execute, a harness tool and another secondary tool are refused with a hint naming the owner and how to ask;
##   3. the workspace rule of a spawn is the team members': a set MMDAPP is explicit; with none set the spawn names a place or a path; an unresolved name is refused;
##   4. RootSession and the floor tools stay allowed;
##   6. a session that was not minted by RootSession is held to none of this;
##   7. the profile is the rows of magic-coordinator.root-harness.routine, complete over the served tools, and the mint records the routine;
##   8. the calls above are sent with no wait for the mint, as a parallel client may: none of them runs ungated.
## Offline and self-contained in its scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigField="$rigHere/harness/AgentsHarnessJsonField.awk"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] && [ -f "$rigField" ] || rigRefuse "the tooling is not at the origin this workspace resolves"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRootHarnessProfileCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigHolds(){ case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac ; }
rigCall(){ ## id, tool, arguments object
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
rigLine(){ ## wire file, id -- the answer line of that id
	LC_ALL=C grep "\"id\":$2," "$1" 2> /dev/null | head -1
}

## ONE SERVER LIFE WITH A MINTED SESSION.
mkdir -p "$rigTmp/root/.local"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
	rigCall 3 RootSession '{"operation":"mint"}'
	## Requests are parsed in parallel, and the calls are sent at once, with no wait for the mint's answer: a call that arrives while the mint is pending
	## waits for it or is refused, never run ungated (fail closed).
	rigCall 4 execute '{"command":"echo ran-in-root"}'
	rigCall 5 Read '{"file_path":"/etc/hosts"}'
	rigCall 6 DistroAgentsSlack '{"operation":"--slack-whoami"}'
	rigCall 10 RootSession '{"operation":"info"}'
} | MMDAPP="$rigTmp/root" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team" bash "$rigTool" --intern-mcp-server --run > "$rigTmp/wire" 2> "$rigTmp/err" || :
[ -s "$rigTmp/wire" ] || { sed 's/^/    /' "$rigTmp/err" >&2 ; rigRefuse "the server answered nothing" ; }

echo "-- 1. the tool list --"
rigList="$( rigLine "$rigTmp/wire" 2 )"
rigAssert "AgentDispatcherTools is listed, once" "$( printf '%s' "$rigList" | LC_ALL=C grep -o '"name":"AgentDispatcherTools"' | wc -l | tr -d ' ' )" "1"

echo "-- 2. the root-harness session is held to its profile --"
rigHint='root-harness'
for rigCase in "4:execute" "5:Read" "6:DistroAgentsSlack" ; do
	rigAnswer="$( rigLine "$rigTmp/wire" "${rigCase%%:*}" )"
	rigAssert "${rigCase#*:} is refused, naming the profile, the owner and how to ask" \
		"$( rigHolds "$rigAnswer" 'root-harness' ):$( rigHolds "$rigAnswer" 'human-owner' ):$( rigHolds "$rigAnswer" 'RequestPermission' )" "yes:yes:yes"
done
rigAssert "execute did not run" "$( rigHolds "$( rigLine "$rigTmp/wire" 4 )" 'ran-in-root' )" "no"

echo "-- 4. what stays allowed --"
rigAssert "RootSession info answers" "$( rigHolds "$( rigLine "$rigTmp/wire" 10 )" 'root-harness' ):$( rigHolds "$( rigLine "$rigTmp/wire" 10 )" 'not available to the root-harness' )" "yes:no"

echo "-- 3. the workspace rule of a spawn, with the places API stood in: the team members' rule --"
## A set MMDAPP is explicit and needs no workspace argument; with none set (the tool file derived it) the spawn names one, a place name that resolves or a path; a name that
## does not resolve is refused whoever calls. No session kind is special-cased.
( 
	export MMDAPP="$rigTmp/root"
	. "$rigHere/session/AgentsTools.CoordinatorSpawn.include" 2> /dev/null || { echo "no-include" ; exit 0 ; }
	LocalToolsPlacesResolve(){ case "$2" in rig-known) printf '%s' "$rigTmp/root" ;; *) return 1 ;; esac ; }
	rigGate(){ ## implied (yes|no), arguments... -- taken or refused
		if [ "$1" = yes ] ; then export MDAT_MMDAPP_IMPLIED=1 ; else unset MDAT_MMDAPP_IMPLIED ; fi
		shift
		AgentsToolsCoordinatorSpawnGate --spawn-run "$@" > /dev/null 2>&1 && printf taken || printf refused
	}
	printf 'none-implied=%s|none-set=%s|known=%s|path=%s|nodir=%s|unknown-set=%s\n' \
		"$( rigGate yes --routine-default )" "$( rigGate no --routine-default )" \
		"$( rigGate yes --select-workspace rig-known --routine-default )" "$( rigGate yes --select-workspace "$rigTmp/root" --routine-default )" "$( rigGate yes --select-workspace /no/such/dir --routine-default )" \
		"$( rigGate no --select-workspace rig-unknown --routine-default )"
) > "$rigTmp/place" 2>&1
rigAssert "no MMDAPP and no workspace is refused; a set MMDAPP needs none; a resolved name and a directory are taken; a missing directory and an unresolved name are refused" "$( cat "$rigTmp/place" )" "none-implied=refused|none-set=taken|known=taken|path=taken|nodir=refused|unknown-set=refused"
rigAssert "the refusal names the way to list the places" "$( ( export MMDAPP="$rigTmp/root" MDAT_MMDAPP_IMPLIED=1 ; . "$rigHere/session/AgentsTools.CoordinatorSpawn.include" ; AgentsToolsCoordinatorSpawnGate --spawn-run --routine-default 2>&1 ) | LC_ALL=C grep -c -- '--manager-place-list' )" "1"

echo "-- 3b. the two forms of the one spawn, and who may use it --"
( 
	export MMDAPP="$rigTmp/root"
	. "$rigHere/session/AgentsTools.CoordinatorSpawn.include" 2> /dev/null || { echo "no-include" ; exit 0 ; }
	printf 'routine=%s|default=%s|member=%s|none=%s|option=%s\n' \
		"$( AgentsToolsCoordinatorSpawnForm --spawn-run --routine magic-team.discuss )" "$( AgentsToolsCoordinatorSpawnForm --spawn-run --routine-default )" \
		"$( AgentsToolsCoordinatorSpawnForm --spawn-run keeper-x --description d )" "$( AgentsToolsCoordinatorSpawnForm --spawn-run || printf none )" "$( AgentsToolsCoordinatorSpawnForm --spawn-run --foo || printf none )"
) > "$rigTmp/forms" 2>&1
rigAssert "a routine first starts a coworking session, a member name first starts that member with a prompt, anything else is neither" "$( cat "$rigTmp/forms" )" "routine=session|default=session|member=prompt|none=none|option=none"
( 
	export MMDAPP="$rigTmp/root"
	. "$rigHere/session/AgentsTools.CoordinatorSpawn.include" 2> /dev/null || { echo "no-include" ; exit 0 ; }
	AgentsToolsPermissionHolds(){ [ "$1" = magic-coordinator ] && printf 'standing' ; }
	printf 'console=%s|coordinator=%s|developer=%s\n' \
		"$( unset MDAT_SPAWN_AGENT ; AgentsToolsCoordinatorSpawnAllowed --spawn-run > /dev/null 2>&1 && printf allowed || printf refused )" \
		"$( MDAT_SPAWN_AGENT=magic-coordinator AgentsToolsCoordinatorSpawnAllowed --spawn-run > /dev/null 2>&1 && printf allowed || printf refused )" \
		"$( MDAT_SPAWN_AGENT=magic-developer AgentsToolsCoordinatorSpawnAllowed --spawn-run > /dev/null 2>&1 && printf allowed || printf refused )"
	MDAT_SPAWN_AGENT=magic-developer AgentsToolsCoordinatorSpawnAllowed --spawn-run 2>&1 | LC_ALL=C grep -c -F 'RequestPermission'
) > "$rigTmp/allowed" 2>&1
rigAssert "the console and the coordinator (a standing row) may; a member with no allow-tool row is refused, with the way to ask" "$( cat "$rigTmp/allowed" | tr '\n' ' ' )" "console=allowed|coordinator=allowed|developer=refused 1 "
rigAssert "the Agent tool is kept as a stub that makes the same spawn and says where it went" "$( LC_ALL=C grep -c -F 'MOVED: Agent is replaced by AgentDispatcherTools operation=--spawn-run' "$rigHere/harness/AgentsHarnessRun.include" )" "1"
rigAssert "the coordinator's standing row is declared in the package" "$( LC_ALL=C grep -c -F 'allow-tool:magic-coordinator:AgentDispatcherTools' "$rigHere/../project.inf" )" "1"

echo "-- 6. a session RootSession did not mint is held to none of this --"
mkdir -p "$rigTmp/plain/.local"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	rigCall 2 DistroAgentsSlack '{"operation":"--slack-whoami"}'
} | MMDAPP="$rigTmp/plain" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --intern-mcp-server --run > "$rigTmp/wire2" 2> "$rigTmp/err2" || :
rigAssert "with no minted session the same call carries no root-harness hint" "$( rigHolds "$( rigLine "$rigTmp/wire2" 2 )" 'root-harness' )" "no"

echo "-- 7. the profile is the routine's rows, and no served tool escapes it --"
## The tools a server serves: the harness tools (the wire), the secondary tools, execute and RootSession. A tool is allowed to a root-harness session when it is a floor tool,
## RootSession or AgentDispatcherTools; every other is named by a deny-tool row of magic-coordinator.root-harness.routine, so a tool added later and left out of both fails here.
rigRoutineFile="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-coordinator/magic-coordinator.root-harness.routine.md"
rigRows="$( LC_ALL=C sed -n 's/^access-control: //p' "$rigRoutineFile" | head -1 )"
rigServed="$( LC_ALL=C grep -o '"function":{"name":"[A-Za-z]*"' "$rigHere/harness/AgentsOpenAiChatWire.sh" | LC_ALL=C sed 's/.*"name":"//; s/"//' ) execute"
rigSecondary="$( ( . "$rigHere/harness/AgentsContext.FrontTable.include" ; printf '%s' "$agentsFrontSecondary" ) | LC_ALL=C tr '\n' ' ' )"
rigFloor="$( ( . "$rigHere/grants/AgentsTools.PermissionHolds.include" ; printf '%s' "$agentsPermissionFloorTools" ) )"
rigEscaped=""
for rigTool7 in $rigServed $rigSecondary ; do
	case " $rigFloor RootSession AgentDispatcherTools " in *" $rigTool7 "*) continue ;; esac
	case ", $rigRows," in *", participants:deny-tool:$rigTool7,"*) ;; *) rigEscaped="$rigEscaped $rigTool7" ;; esac
done
rigAssert "every served tool outside the floor, RootSession and AgentDispatcherTools is denied by a row" "[${rigEscaped# }]" "[]"
rigAllowedDenied=""
for rigTool7 in $rigFloor RootSession AgentDispatcherTools ; do
	case ", $rigRows," in
		*":deny-tool:$rigTool7,"*) rigAllowedDenied="$rigAllowedDenied $rigTool7" ;;
	esac
done
rigAssert "and no row denies a tool the profile allows" "[${rigAllowedDenied# }]" "[]"
rigAssert "the session minted runs that routine: its folder records it" "$( ls "$rigTmp"/root/.local/agents/sessions/*/root-session.routine 2> /dev/null | head -1 | xargs cat 2> /dev/null )" "magic-coordinator.root-harness.routine.md"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ROOT HARNESS PROFILE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'ROOT_HARNESS_PROFILE: OK (%d assertions, offline)\n' "$rigPass"
