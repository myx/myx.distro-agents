#!/usr/bin/env bash
## Behavioural check on --owner-setup-* settings and the team-data default, run rather
## than read, against a scenario workspace built here -- no file of the real workspace
## is read or written. Holds: `--<option> ""` removes a setting exactly as a stdin
## `KEY=` does, in every domain; a required key is still refused; and with
## TEAM_DATA_DIRECTORY unset the team data is the workspace's own
## .local/agents/team-data-root, for the resolver, --owner-setup-storage --check and
## the main-loop readiness floor alike; and a missing access fragment is a WARN while
## grants.index is usable, a FAIL only with neither. Offline: no host, no network, no credential.
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

## SLACK_AUTH_IDENTITY in --magic-heartbeat-config-check: auth.test is answered by a
## stand-in curl first on PATH, so no request leaves this host.
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\ncat >/dev/null\nprintf %%s "$RIG_AUTH_REPLY"\n' > "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl"
export RIG_AUTH_REPLY='{"ok":true,"user_id":"URIG00001"}'
rigIdentity(){ PATH="$rigTmp/bin:$PATH" rigRun --magic-heartbeat-config-check | grep -A2 '^SLACK_AUTH_IDENTITY:' ; }
rigExpect "identity: no SLACK_USER_TOKEN is a WARN" \
	"$( rigIdentity )" "SLACK_AUTH_IDENTITY: WARN"
printf 'xoxp-rig' | rigRun --agents-config-option magic-coordinator --upsert-from-stdin SLACK_USER_TOKEN >/dev/null
grep -q '^SLACK_USER_TOKEN=' "$rigWs/.local/.agents/magic-coordinator.agent.env" 2>/dev/null \
	|| rigRefuse "could not store a SLACK_USER_TOKEN, so no identity verdict below would mean anything"
rigExpect "identity: auth.test's user_id is reported as OK" \
	"$( rigIdentity )" "user_id: URIG00001"
export RIG_AUTH_REPLY='{"ok":false,"error":"invalid_auth"}'
rigExpect "identity: auth.test with no user_id is a WARN" \
	"$( rigIdentity )" "SLACK_AUTH_IDENTITY: WARN"

## A home that has never held a skills directory: the lock beside the workspace's own registry must still be taken.
rigInstallHome="$rigTmp/home-without-skills"
mkdir -p "$rigInstallHome"
rigInstallOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigInstallHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --install-claude-permissions 2>&1 )"
[ -f "$rigInstallHome/.claude/settings.json" ] || rigRefuse "--install-claude-permissions never reached its settings step, so the registry lock below was not exercised"
rigExpect "install-claude-permissions without ~/.claude/skills is not reported busy" \
	"$( case "$rigInstallOut" in (*"registry busy"*) printf busy ;; (*) printf not-busy ;; esac )" "not-busy"
rigExpect "and it writes no permissions registry: --make-agents-indices does" \
	"$( [ -f "$rigWs/.local/agents/permissions.registry" ] && printf present || printf absent )" "absent"

## A workspace with no source folder declares no grant, which is a state, not a failure: the
## grants step of --make-agents-indices says so as a note, exits 0, and keeps the registry as it stood.
rigUntrustedRc=0
rigUntrustedOut="$( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigInstallHome" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --make-agents-indices 2>&1 )" || rigUntrustedRc=$?
rigExpect "control: this rig really has no source folder, so the note is printed" \
	"$rigUntrustedOut" "has no source folder, so none declares a grant"
rigExpect "a workspace with no source ends with exit 0" \
	"rc=$rigUntrustedRc" "rc=0"
rigExpect "and its note opens with the note mark, not a warning or an error mark" \
	"$( printf '%s\n' "$rigUntrustedOut" | grep 'has no source folder' | head -1 | cut -c1-1 )" "#"
rigExpect "and the grants step reports no error" \
	"$( printf '%s\n' "$rigUntrustedOut" | grep -c 'ERROR.*make-agents-indices' )" "0"
rigExpect "and the registry is kept as it stood, none" \
	"$( [ -f "$rigWs/.local/agents/permissions.registry" ] && printf present || printf absent )" "absent"
rigExpect "and the settings file is still there" \
	"$( [ -f "$rigInstallHome/.claude/settings.json" ] && printf present || printf absent )" "present"

## CLIENT_ACCESS_ROOTS: the access fragment is only a fallback for the member roots off
## grants.index, so its absence is a WARN while the index is usable, and a FAIL only with
## neither. A stand-in claude first on PATH, so no vendor binary runs. The index is made
## unusable by pointing harnessHere, the lib directory the grants code loads from, at an
## empty directory, with no index file left in the rig.
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/bin/claude" && chmod +x "$rigTmp/bin/claude"
rm -f -- "$rigWs/.claude/copilot-add-dir.fragment"
rigAccessCheck(){ ## extra env assignments
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SKILLSET_ROOT HOME="$rigInstallHome" PATH="$rigTmp/bin:$PATH" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$@" bash "$rigTool" --owner-setup-claude-native --check 2>&1 ) \
		| grep -A2 '^CLIENT_ACCESS_ROOTS:'
}
rigExpect "access roots: no fragment, grants.index usable, is a WARN" \
	"$( rigAccessCheck RIG_NONE=1 )" "CLIENT_ACCESS_ROOTS: WARN"
mkdir -p "$rigTmp/no-lib"
rm -f -- "$rigWs/.local/agents/grants.index"
rigExpect "access roots: neither grants.index nor a fragment is a FAIL" \
	"$( rigAccessCheck harnessHere="$rigTmp/no-lib" )" "CLIENT_ACCESS_ROOTS: FAIL"
rigExpect "and it says neither gives the roots" \
	"$( rigAccessCheck harnessHere="$rigTmp/no-lib" )" "neither grants.index nor an access fragment"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ OWNER SETUP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'OWNER_SETUP_SETTINGS: OK (%d assertions, offline)\n' "$rigPasses"
