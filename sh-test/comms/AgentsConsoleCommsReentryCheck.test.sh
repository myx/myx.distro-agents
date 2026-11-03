#!/usr/bin/env bash
## Behavioural check on S6.24 of the refactorings epic: a comms operation run from a plain
## console, on a PATH that holds no `DistroAgentsTools` command, reaches its own
## implementation. The member stubs of the comms includes handed their arm to
## `DistroAgentsTools`, which is a function of the dispatcher and no command outside it, so
## `--confluence-space-list`, `--jira-board-list`, `--email-check`, `--trello-read` and
## `--google-whoami` exited 127 with `DistroAgentsTools: command not found`. Held:
##   1. THE SHAPE. The rig's console is bare: `DistroAgentsTools` is no command on its PATH,
##      and no wrapper of the rig's supplies one.
##   2. THE OPERATIONS. Every comms operation a console names runs past its stub: the run
##      leaves no `command not found` mark, and its status is not 127.
##   3. THE IMPLEMENTATION RAN. Each run answers with its own implementation's missing-
##      credential line, so "no mark" is never read off a run that stopped somewhere else.
##   4. THE INSTRUMENT. The mark reader is run on a log with a planted `command not found`
##      line and on a clean one: a reader that cannot fail is no check.
## Red recipe: on the includes as they stand before S6.24, section 2 fails on twelve
## operations with `... : line 14: DistroAgentsTools: command not found` and their status is
## 127; sections 1, 3 and 4 pass.
## Offline: a workspace, a member set and a fake curl of the rig's own under
## $MMDAPP/.local/agents/scratch/sh-test; no socket is opened, and no credential is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/DistroAgentsAtlassian.fn.sh" ] || rigRefuse "no package at the origin this workspace resolves: $rigPackage"

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleCommsReentryCheck )" || exit 1
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

## THE BARE CONSOLE. The rig's bin holds a fake curl alone: no DistroAgentsTools command, and
## no wrapper of any kind beside it.
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/data" "$rigTmp/skills/magic-coordinator" "$rigTmp/home"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf '#!/bin/sh\nprintf "200\\n"\nexit 0\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

rigRun(){ ## tool file, then the arguments -- the console's own run of it
	local rigFile="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash "$rigPackage/sh-scripts/$rigFile.fn.sh" "$@" > "$rigTmp/call.out" 2>&1
	printf '%s' "$?"
}
rigMarkCount(){ LC_ALL=C grep -c -F 'command not found' "$rigTmp/call.out" || : ; }

echo "-- 1. the shape of the console --"
rigAssert "the rig's console has no DistroAgentsTools command on PATH" \
	"$( env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" bash -c 'command -v DistroAgentsTools || printf none' )" "none"
rigAssert "and no file of the rig's bin stands in for it" "$( LC_ALL=C ls "$rigTmp/bin" )" "curl"

echo "-- 4. the instrument: the mark reader on logs made by hand --"
printf 'x\n/x/sh-lib/comms/AgentsTools.MemberCommsConfluence.include: line 14: DistroAgentsTools: command not found\n' > "$rigTmp/log.plagued"
printf 'x\n# page 1: nothing to read\n' > "$rigTmp/log.clean"
rigAssert "the reader counts a planted mark" "$( LC_ALL=C grep -c -F 'command not found' "$rigTmp/log.plagued" )" 1
rigAssert "and counts nothing on a clean log" "$( LC_ALL=C grep -c -F 'command not found' "$rigTmp/log.clean" || : )" 0

echo "-- 2 and 3. every comms operation a console names --"
## tool file, operation, the status its implementation answers with, the words of its own line
rigCase(){
	local rigFile="$1" rigOp="$2" rigWantRc="$3" rigWantText="$4"
	shift 4
	local rigRc ; rigRc="$( rigRun "$rigFile" "$rigOp" "$@" )"
	rigAssert "$rigFile $rigOp leaves no command-not-found mark" "$( rigMarkCount )" 0
	rigAssert "$rigFile $rigOp answers as its implementation does, not 127" "$rigRc" "$rigWantRc"
	rigAssert "$rigFile $rigOp reaches its own implementation's line" \
		"$( LC_ALL=C grep -c -F -- "$rigWantText" "$rigTmp/call.out" )" 1
}
rigCase DistroAgentsAtlassian --confluence-space-list 6 "--confluence-space-list: CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN missing" magic-coordinator
rigCase DistroAgentsAtlassian --confluence-page-read 6 "--confluence-page-read: CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN missing" magic-coordinator 12345
rigCase DistroAgentsAtlassian --jira-board-list 6 "--jira-board-list: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator
rigCase DistroAgentsAtlassian --jira-board-read 6 "--jira-board-read: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator 7
rigCase DistroAgentsAtlassian --jira-board-issue-search 6 "--jira-board-issue-search: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator 7
rigCase DistroAgentsAtlassian --jira-issue-read 6 "--jira-issue-read: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator ABC-1
rigCase DistroAgentsAtlassian --jira-sprint-list 6 "--jira-sprint-list: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator 7
rigCase DistroAgentsAtlassian --jira-sprint-issue-search 6 "--jira-sprint-issue-search: JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing" magic-coordinator 7
rigCase DistroAgentsMail --email-check 1 "--email-check: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set" magic-coordinator
rigCase DistroAgentsMail --email-read 1 "--email-read: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set" magic-coordinator 5
rigCase DistroAgentsTrello --trello-read 1 "--trello-read: TRELLO_KEY/TRELLO_TOKEN not fully set" magic-coordinator abc123
rigCase DistroAgentsGoogle --google-whoami 1 "--google-whoami: GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET/GOOGLE_REFRESH_TOKEN not fully set" magic-coordinator

echo "-- 5. the include-level sites, driven with no dispatcher function either --"
## A shell that sources the include and calls the function holding the site. DistroAgentsTools is
## neither a command here nor a function: an include that calls the tool's own function works only
## inside the dispatcher, which is the class the review names.
rigDrive(){ ## the snippet, its stdout and stderr into call.out, then its status
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off MDAT_TEAM_DATA_COMMIT_THREAD=off \
		MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off MDSC_CMD=probe RIG_SH="$rigPackage/sh-lib" RIG_TMP="$rigTmp" \
		bash -c "$1" > "$rigTmp/call.out" 2>&1
	printf '%s' "$?"
}
mkdir -p "$rigTmp/skills/client-rig" "$rigTmp/temp"
printf 'rig\n' > "$rigTmp/skills/client-rig/client-rig.basic.md"
rigAssert "the measured shell defines no dispatcher function" \
	"$( env -i PATH="$rigTmp/bin:/usr/bin:/bin" bash -c 'type DistroAgentsTools > /dev/null 2>&1 && printf function || printf none' )" "none"

## The client operation is driven the console's own way, through its tool file: the include relies
## on the bare-name gate its caller has loaded, as every include of the family does.
rigRc="$( rigRun AgentDispatcherTools --client-operation-run magic-coordinator --client-comms-trello-check client-rig )"
rigAssert "MagicClient --client-operation-run leaves no command-not-found mark" "$( rigMarkCount )" 0
rigAssert "and it reaches the client stub's own line" \
	"$( LC_ALL=C grep -c -F 'TRELLO_KEY/TRELLO_TOKEN not fully set' "$rigTmp/call.out" )" 1

rigAssert "MemberWaitChat's scan probe leaves no command-not-found mark" \
	"$( rigDrive 'probe(){ local MDSC_CMD=probe
	. "$RIG_SH/member/AgentsTools.MemberWaitChat.include" > /dev/null 2>&1
	AgentsWaitProbeScan magic-coordinator grooming "$RIG_TMP/temp/p.out" "$RIG_TMP/temp/p.out" ; }
	probe' > /dev/null ; LC_ALL=C grep -c -F 'command not found' "$rigTmp/call.out" || : )" "0"

rigDrive 'probe(){ local MDSC_CMD=probe ; set -- --intern-op-slack-check-scopes magic-coordinator --scope-source --slack-read --context probe
	. "$RIG_SH/comms/AgentsTools.CommsSlack.include" ; }
	probe' > /dev/null
rigAssert "CommsSlack reads a --scope-source's declaration, rather than finding none" \
	"$( LC_ALL=C grep -c -F 'returned no scope declaration' "$rigTmp/call.out" || : )" 0

rigDrive 'probe(){ local MDSC_CMD=probe ; set -- --intern-root-harness --non-interactive --routine magic-team.coworking.routine
	. "$RIG_SH/harness/AgentsTools.InternRootHarness.include" ; }
	probe' > /dev/null
rigAssert "InternRootHarness's root pass leaves no command-not-found mark" "$( rigMarkCount )" 0

## The row is `<mark> <first> <family> <alias>`. Read with no override stored, then with one: a
## site that cannot reach the setting's own include answers its default both times.
rigRow(){ rigDrive 'probe(){ local MDSC_CMD=probe ; set -- --get-roster
	. "$RIG_SH/team-data/AgentsTools.Registries.include" > /dev/null 2>&1
	AgentsToolsRegistryMemberNamesRead magic-coordinator ; }
	probe' > /dev/null ; LC_ALL=C tail -1 "$rigTmp/call.out" | LC_ALL=C sed 's/^[[:space:]]*//; s/[[:space:]]*$//' ; }
rigAssert "Registries answers the default alias when none is stored, and no mark" "$( rigRow ):$( rigMarkCount )" "- - - -:0"
env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_TEAM_DATA_COMMIT_THREAD=off \
	bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-coordinator --upsert ALIAS rigalias > /dev/null 2>&1
rigAssert "Registries answers the stored alias once one is set, and no mark" "$( rigRow ):$( rigMarkCount )" "- - - rigalias:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONSOLE COMMS REENTRY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_COMMS_REENTRY: OK (%d assertions, 17 sites, offline)\n' "$rigPassCount"
