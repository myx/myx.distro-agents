#!/usr/bin/env bash
## Behavioural check on --owner-setup-* settings and the team-data default, run rather
## than read, against a scenario workspace built here -- no file of the real workspace
## is read or written. Holds: `--<option> ""` removes a setting exactly as a stdin
## `KEY=` does, in every domain; a required key is still refused; and with
## TEAM_DATA_DIRECTORY unset the team data is the workspace's own
## .local/agents/team-data-root, for the resolver, --owner-setup-storage --check and
## the main-loop readiness floor alike. Offline: no host, no network, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsOwnerSetupCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents"

## The scenario IS the workspace: nothing inherited may point the tool elsewhere.
rigRun(){
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" "$@" 2>&1 )
}

rigFails=0 rigPasses=0
rigExpect(){ ## what is asserted, output, the text it must hold
	case "$2" in
		*"$3"*)
			printf '  PASS  %s\n' "$1"
			rigPasses=$(( rigPasses + 1 ))
		;;
		*)
			printf '  FAIL  %s\n        want: %s\n        got:  %s\n' "$1" "$3" "$( printf '%s' "$2" | grep -v 'SystemContext' | head -3 )"
			rigFails=$(( rigFails + 1 ))
		;;
	esac
}

## The subject has to be reachable before anything is asserted about it.
rigRun --owner-setup-storage --team-data-directory "$rigWs/shared" --apply >/dev/null
grep -q "^TEAM_DATA_DIRECTORY=$rigWs/shared\$" "$rigWs/.local/.agents/magic-coordinator.agent.env" 2>/dev/null \
	|| rigRefuse "could not store a value through --owner-setup-storage --apply, so no removal below would mean anything"

rigExpect "a set TEAM_DATA_DIRECTORY overrides the default" \
	"$( rigRun --intern-config-board-location )" "$rigWs/shared"
rigExpect "storage: --team-data-directory \"\" removes the setting" \
	"$( rigRun --owner-setup-storage --team-data-directory "" --apply )" "TEAM_DATA_DIRECTORY removed from"
rigExpect "and it is gone from the stored scope" \
	"$( grep -c '^TEAM_DATA_DIRECTORY=' "$rigWs/.local/.agents/magic-coordinator.agent.env" )" "0"
rigRun --owner-setup-storage --team-data-directory "$rigWs/shared" --apply >/dev/null
rigExpect "storage: stdin TEAM_DATA_DIRECTORY= removes it the same way" \
	"$( printf 'TEAM_DATA_DIRECTORY=\n' | rigRun --owner-setup-storage --values-from-stdin --apply )" "TEAM_DATA_DIRECTORY removed from"

## Unset through the config layer itself, so the default is asserted whether or not
## the removals above worked.
rigRun --agents-config-option magic-coordinator --delete TEAM_DATA_DIRECTORY >/dev/null
! grep -q '^TEAM_DATA_DIRECTORY=' "$rigWs/.local/.agents/magic-coordinator.agent.env" \
	|| rigRefuse "could not unset TEAM_DATA_DIRECTORY, so no default below would be measured"
rigExpect "unset, the resolver answers the workspace's own store" \
	"$( rigRun --intern-config-board-location )" "$rigWs/.local/agents/team-data-root"
rigExpect "unset, --owner-setup-storage --check passes" \
	"$( rigRun --owner-setup-storage --check ; echo "rc=$?" )" "rc=0"
rigExpect "and names the store it resolves to" \
	"$( rigRun --owner-setup-storage --check )" "$rigWs/.local/agents/team-data-root"
## Nothing is spawned here: this scenario has no comms and no agent CLI, so the floor
## refuses the loop -- asserted below, beside the one floor item under test.
rigExpect "unset, the main-loop floor counts team data as ready" \
	"$( rigRun --intern-main-loop --one | grep 'Team data directory' )" "ready"
rigExpect "and the loop still refuses to start on the floor it lacks" \
	"$( rigRun --intern-main-loop --one )" "NOT READY"

rigRun --owner-setup-storage --team-data-git-remote "$rigTmp/remote.git" --apply >/dev/null
rigExpect "storage: an optional key is removed" \
	"$( rigRun --owner-setup-storage --team-data-git-remote "" --apply )" "TEAM_DATA_GIT_REMOTE removed from"
rigExpect "storage: removing it again reports it not set" \
	"$( rigRun --owner-setup-storage --team-data-git-remote "" --apply )" "TEAM_DATA_GIT_REMOTE is not set"

rigRun --owner-setup-slack --slack-channel-magic-team C00000000 --slack-channel-human-owner U00000000 \
	--slack-channel-event-track C11111111 --apply >/dev/null
rigExpect "slack: an optional key is removed" \
	"$( rigRun --owner-setup-slack --slack-channel-event-track "" --apply )" "SLACK_CHANNEL_EVENT_TRACK removed from"
rigExpect "and it is gone from the stored scope" \
	"$( grep -c '^SLACK_CHANNEL_EVENT_TRACK=' "$rigWs/.local/.agents/magic-team.agent.env" )" "0"
rigExpect "slack: a required key is still refused" \
	"$( rigRun --owner-setup-slack --slack-channel-magic-team "" --apply )" "a value-less SLACK_CHANNEL_MAGIC_TEAM= removes it"
rigExpect "and it is still stored" \
	"$( grep -c '^SLACK_CHANNEL_MAGIC_TEAM=C00000000$' "$rigWs/.local/.agents/magic-team.agent.env" )" "1"
rigExpect "a flag with no value at all is still refused" \
	"$( rigRun --owner-setup-storage --team-data-git-remote )" "a value is required"

## A home that has never held a skills directory: the lock beside the registry must still be taken.
rigInstallHome="$rigTmp/home-without-skills"
mkdir -p "$rigInstallHome"
rigInstallOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigInstallHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --install-claude-permissions 2>&1 )"
[ -f "$rigInstallHome/.claude/settings.json" ] || rigRefuse "--install-claude-permissions never reached its settings step, so the registry lock below was not exercised"
rigExpect "install-claude-permissions without ~/.claude/skills is not reported busy" \
	"$( case "$rigInstallOut" in (*"registry busy"*) printf busy ;; (*) printf not-busy ;; esac )" "not-busy"
rigExpect "and its permissions registry is created" \
	"$( [ -f "$rigInstallHome/.claude/skills/.linked.magic-team.permissions.txt" ] && printf present || printf absent )" "present"

## A workspace whose scan selects no project is a state, not a failure: the run says so as a warning, exits 0, and
## keeps the settings the registry already holds.
rigUntrustedRc=0
rigUntrustedOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigInstallHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --install-claude-permissions 2>&1 )" || rigUntrustedRc=$?
rigExpect "control: this rig's scan really was not trusted, so the warning is printed" \
	"$rigUntrustedOut" "declared allow-write was not determined"
rigExpect "an untrusted scan ends with exit 0" \
	"rc=$rigUntrustedRc" "rc=0"
rigExpect "and its warning opens with the warning mark, not an error mark" \
	"$( printf '%s\n' "$rigUntrustedOut" | grep 'declared allow-write was not determined' | head -1 | cut -c1-4 )" "🙋"
rigExpect "and it is not reported as an error" \
	"$( printf '%s\n' "$rigUntrustedOut" | grep -c 'ERROR.*install-claude-permissions.*untrusted' )" "0"
rigExpect "and the settings file is still there" \
	"$( [ -f "$rigInstallHome/.claude/settings.json" ] && printf present || printf absent )" "present"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ OWNER SETUP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'OWNER_SETUP_SETTINGS: OK (%d assertions, offline)\n' "$rigPasses"
