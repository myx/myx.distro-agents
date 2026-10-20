#!/usr/bin/env bash
## Behavioural check on --owner-clear-just-agents (F13.2): the clear of a Just Agents workspace clears configuration settings, and only those.
## Held, run and not read, in a rig workspace of this check's own:
##   1. --check, which is also what a bare call does, names the settings that are set and changes nothing; no value is printed.
##   2. --apply clears exactly the six settings that do not belong in Just Agents, default -- TEAM_DATA_DIRECTORY (scope magic-coordinator),
##      TEAM_DATA_GIT_REMOTE, TEAM_DATA_BRANCH, TEAM_DATA_GIT_USER_NAME, TEAM_DATA_GIT_USER_EMAIL and MDAT_WORKSPACE_MODE (scope magic-team) --
##      through the settings writer; every other setting of both scopes stands as it was, and the workspace is just agents, by default.
##   3. NEVER ANY DATA: the team-data folder, .local/agents and .local/temp hold what they held, byte for byte.
##   4. A second --apply has nothing to clear; an option it does not know, and a word after the option, are refused with nothing changed.
## Offline, rig tree only; no value of a setting is printed anywhere (the values here carry a marker this check looks for in the output).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwnerClearJustAgentsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigScopes="$rigWs/.local/.agents"
mkdir -p "$rigScopes" "$rigHome" "$rigWs/.local/temp" "$rigWs/.local/agents/team-data-root/board/running" "$rigWs/.local/agents/spawned"
## The settings: the six, with a marker in each value, and others that stay.
rigSix="TEAM_DATA_GIT_REMOTE TEAM_DATA_BRANCH TEAM_DATA_GIT_USER_NAME TEAM_DATA_GIT_USER_EMAIL MDAT_WORKSPACE_MODE"
rigSettings(){ ## write the scopes as the rig starts
	printf 'TEAM_DATA_DIRECTORY=/rig/MARKER-dir\nCONFLUENCE_SITE=rig-site-MARKER\n' > "$rigScopes/magic-coordinator.agent.env"
	printf 'SPAWN_CLI_SERVICE=claude-native\nTEAM_DATA_GIT_REMOTE=git@rig.invalid:MARKER-remote.git\nTEAM_DATA_BRANCH=MARKER-branch\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nTEAM_DATA_GIT_USER_NAME=MARKER name\nTEAM_DATA_GIT_USER_EMAIL=marker@rig.invalid\nMDAT_WORKSPACE_MODE=team-rig\n' > "$rigScopes/magic-team.agent.env"
}
rigSettings
printf 'board item\n' > "$rigWs/.local/agents/team-data-root/board/running/task-rig.md"
printf 'stale\n' > "$rigWs/.local/temp/stale.txt"
printf 'record\n' > "$rigWs/.local/agents/spawned/rec"
rigRun(){ ## the words after the operation -- stdout in out, stderr in err, rc in rigRc
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" --owner-clear-just-agents "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
}
rigSum(){ ## a checksum of what a folder holds, names and contents
	( cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r sumFile ; do printf '%s ' "$sumFile" ; cksum < "$sumFile" ; done ) | cksum
}
rigDataSum(){ ## everything of the workspace but the settings
	( cd "$rigWs/.local" && find . -type f ! -path './.agents/*' | LC_ALL=C sort | while IFS= read -r sumFile ; do printf '%s ' "$sumFile" ; cksum < "$sumFile" ; done ) | cksum
}
rigPrinted(){ ## how many lines of stdout and stderr show a value
	cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -e 'MARKER' -e 'rig.invalid' -e 'team-rig' || :
}
rigHas(){ ## scope, key -- yes where the scope holds the key
	LC_ALL=C grep -q "^$2=" "$rigScopes/$1.agent.env" 2> /dev/null && printf yes || printf no
}
rigBeforeAll="$( rigSum "$rigScopes" )" rigBeforeData="$( rigDataSum )"

echo "-- 1. --check, and a bare call --"
rigRun --check
rigAssert "--check ends 0" "$rigRc" 0
rigAssert "it names each of the six as set, and says --apply clears them" "$( LC_ALL=C grep -c -E '^SETTING: (magic-coordinator TEAM_DATA_DIRECTORY|magic-team (TEAM_DATA_GIT_REMOTE|TEAM_DATA_BRANCH|TEAM_DATA_GIT_USER_NAME|TEAM_DATA_GIT_USER_EMAIL|MDAT_WORKSPACE_MODE)) set$' "$rigTmp/out" ):$( LC_ALL=C grep -c -x 'CHECK: 6 of 6 set; --apply clears them' "$rigTmp/out" )" 6:1
rigAssert "it names no other setting" "$( LC_ALL=C grep -c '^SETTING: ' "$rigTmp/out" )" 6
rigAssert "it prints no value, and not the mode either" "$( rigPrinted )" 0
rigAssert "it made no store, though a remote is set and the mode is a team rig (no clone)" "$( [ -e "$rigWs/.local/agents/team-data-root/.git" ] && printf cloned || printf none )" none
rigAssert "it changes nothing: settings and data as they were" "$( rigSum "$rigScopes" ):$( rigDataSum )" "$rigBeforeAll:$rigBeforeData"
rigRun
rigAssert "a bare call is --check" "$rigRc:$( LC_ALL=C grep -c -x 'CHECK: 6 of 6 set; --apply clears them' "$rigTmp/out" ):$( rigSum "$rigScopes" )" "0:1:$rigBeforeAll"

echo "-- 2 and 3. --apply --"
rigRun --apply
rigAssert "--apply ends 0, and says it cleared six" "$rigRc:$( LC_ALL=C grep -c -x 'CLEARED: 6' "$rigTmp/out" )" 0:1
rigAssert "it prints no value" "$( rigPrinted )" 0
rigAssert "the six settings are gone" "$( rigHas magic-coordinator TEAM_DATA_DIRECTORY ) $( for rigKey in $rigSix ; do printf '%s ' "$( rigHas magic-team $rigKey )" ; done )" "no no no no no no "
rigAssert "every other setting stands as it was" "$( rigHas magic-coordinator CONFLUENCE_SITE ) $( rigHas magic-team SPAWN_CLI_SERVICE ) $( rigHas magic-team SLACK_CHANNEL_MAGIC_TEAM ):$( LC_ALL=C grep -c -x 'CONFLUENCE_SITE=rig-site-MARKER' "$rigScopes/magic-coordinator.agent.env" ):$( LC_ALL=C grep -c -x -e 'SPAWN_CLI_SERVICE=claude-native' -e 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001' "$rigScopes/magic-team.agent.env" )" "yes yes yes:1:2"
rigAssert "no data touched: the team-data folder, .local/agents and .local/temp hold what they held" "$( rigDataSum )" "$rigBeforeData"
rigAssert "the board item of the rig is still there" "$( [ -f "$rigWs/.local/agents/team-data-root/board/running/task-rig.md" ] && printf yes || printf no )" yes
rigAssert "the workspace is just agents, by default, again" "$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataGate.include" ; AgentsToolsWorkspaceMode' 2> /dev/null )" "just-agents default"

echo "-- 4. again, and what is refused --"
rigAfterAll="$( rigSum "$rigScopes" )"
rigRun --apply
rigAssert "a second --apply has nothing to clear, and changes nothing" "$rigRc:$( LC_ALL=C grep -c -x 'CLEARED: 0' "$rigTmp/out" ):$( rigSum "$rigScopes" )" "0:1:$rigAfterAll"
rigRun --check
rigAssert "a check after it finds none set" "$rigRc:$( LC_ALL=C grep -c -x 'CHECK: 0 of 6 set; nothing to clear' "$rigTmp/out" )" 0:1
rigSettings
rigBeforeAll="$( rigSum "$rigScopes" )"
rigRun --soon
rigAssert "an option it does not know is refused, rc 1, nothing changed" "$rigRc:$( rigSum "$rigScopes" )" "1:$rigBeforeAll"
rigRun --apply now
rigAssert "a word after the option is refused, rc 1, nothing changed" "$rigRc:$( rigSum "$rigScopes" )" "1:$rigBeforeAll"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ OWNER CLEAR JUST AGENTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'OWNER_CLEAR_JUST_AGENTS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
