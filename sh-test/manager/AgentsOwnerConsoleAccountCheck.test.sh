#!/usr/bin/env bash
## Behavioural check that the console-to-owner mapping is declared where it is READ:
## HUMAN_OWNER_CONSOLE_ACCOUNT, whose absence made every owner action from the console
## escalate and fail ("no thread of its session is known"), must stand in the magic-team
## scope (a form row, not a raw key) and in the option catalogue, and the authority gate
## must still read that same name. Offline; reads the package only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
## A workspace of its own, with one preset: the team scope is drawn only where a preset stands.
rigWs="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsOwnerConsoleAccountCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigWs"' EXIT
mkdir -p "$rigWs/.local/.agents"
printf 'PRESET_CLI_SERVICE=claude\n' > "$rigWs/.local/.agents/preset-base.agent.env"
## Each call runs in a shell of its own: the scope include's chain ends its process when it
## dispatches, so a test that sourced it in place would end with it.
rigKnown(){ ## scope
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/config/AgentsTools.Preset.include" ; . "$1/manager/AgentsTools.ManagerScopeAgents.include" ; AgentsToolsManagerScopeAgentsKnown "$2"' _ "$rigHere" "$1" 2> /dev/null
}
rigSpec(){ ## key
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/config/AgentsTools.OwnerSetupOptionSpec.include" ; AgentsToolsOwnerSetupOptionSpec "$2"' _ "$rigHere" "$1" 2> /dev/null
}

echo "-- the team's form offers it, as a text setting --"
row="$( rigKnown magic-team | LC_ALL=C grep -e '^HUMAN_OWNER_CONSOLE_ACCOUNT' | cut -f1-3 )"
check "the magic-team scope carries the setting as a text row" "$row" "HUMAN_OWNER_CONSOLE_ACCOUNT	text	-"

echo "-- the option catalogue knows it, and says what unset means --"
spec="$( rigSpec HUMAN_OWNER_CONSOLE_ACCOUNT )"
check "it is a magic-team option" "${spec%%|*}" "magic-team"
case "$spec" in *"human-owner"*|*"human owner"*) mapped="yes" ;; *) mapped="no" ;; esac
check "its words name the human-owner it maps to" "$mapped" "yes"
case "$spec" in *"Unset"*) unsetWords="yes" ;; *) unsetWords="no" ;; esac
check "and what unset means" "$unsetWords" "yes"

echo "-- the reader and the declaration name the same key --"
## The gate itself, called for real against the rig's own magic-team scope (the epic's bug: without the
## setting every owner action from the console escalated and failed).
: "${MDSC_INMODE:=extern}" "${MDLT_OPTION:=--run-from-path $MDLT_ORIGIN}" "${MDSC_OPTION:=--run-from-path $MDLT_ORIGIN}"
export MDSC_INMODE MDLT_OPTION MDSC_OPTION
rigNamed(){ ## member name -- the authority gate's own verdict, as rc
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" -c '. "$1/questions/AgentsTools.Authority.include" ; AgentsToolsAuthorityOwnerNamed "$2"' _ "$rigHere" "$1" > /dev/null 2>&1 ; echo $?
}
printf '%s\n' 'HUMAN_OWNER_CONSOLE_ACCOUNT=myx' > "$rigWs/.local/.agents/magic-team.agent.env"
check "the gate takes the mapped console account as the owner" "$( rigNamed user-myx )" "0"
check "and no other console account" "$( rigNamed user-other )" "1"
check "and no member of the same name as the account" "$( rigNamed myx )" "1"
printf '%s\n' 'HUMAN_OWNER_CONSOLE_ACCOUNT=other' > "$rigWs/.local/.agents/magic-team.agent.env"
check "a changed mapping moves the owner with it (the gate reads the setting, not a built-in name)" "$( rigNamed user-myx ) $( rigNamed user-other )" "1 0"
: > "$rigWs/.local/.agents/magic-team.agent.env"
check "unset maps no one" "$( rigNamed user-myx )" "1"
check "and no member scope offers it" "$( rigKnown magic-tester | LC_ALL=C grep -c -e '^HUMAN_OWNER_CONSOLE_ACCOUNT' )" "0"

if [ "$fail" = 0 ] ; then printf 'OWNER_CONSOLE_ACCOUNT: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ OWNER_CONSOLE_ACCOUNT CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
