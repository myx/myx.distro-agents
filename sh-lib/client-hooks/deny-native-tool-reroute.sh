#!/usr/bin/env bash
## deny-native-tool-reroute.sh -- the PreToolUse hook that routes a *-native agent CLI
## off its own built-in tools and onto this estate's MCP tooling. A REAL SCRIPT: it is
## installed by copying, it runs exactly as it stands here, and nothing is substituted
## into it. What it refuses and what it answers with are below, in full.
##
## The tool being decided arrives as $1, from the PreToolUse entry's own command string
## in .claude/settings.json -- one entry per matcher, each naming its own tool. That
## string is run by a shell, so the name reaches here as an ordinary argument.
##
## Every reroute here is payload-blind: the tool is denied whatever arguments it was
## called with, so stdin is drained and never looked at -- but for TodoWrite, whose
## session id is read from it, below. The drain is there so the
## client does not see a broken pipe. The conditional, path-scoped Read guard is
## deny-memory-md-read.sh, a separate script, because that one has to read the payload
## and it has an allow path.
##
## The one allow path here is the spawn markers below: our own spawned sessions --
## this estate's managed fleet, on whatever backend CLI -- carry MDAT_SPAWN_SESSION_ID
## or MDAT_SPAWN_AGENT. A genuine native-harness session, a human at this CLI's own
## terminal with neither marker set, carries nothing of ours at all. The restriction
## is for that second case only: a spawned session keeps its normal tools, unrerouted.
##
## A reroute names the MCP method to use instead. A refusal naming none sends the caller
## nowhere and it retries the same call.
##
## Which tools are rerouted is stated once, in AgentsTools.ClientToolPolicy.include, and
## the installer writes one entry per name from there. A name that reaches here without a
## case below is the two disagreeing, and the last case DENIES rather than falling through
## silently: a hook that emits no decision reads as ALLOW.
##
## An apostrophe in a reason ends nothing here -- the reasons are double-quoted arguments
## -- but a double quote or a backslash would end the JSON string early, so the prose is
## written to need neither.

hookInput="$( cat )"

## Our own spawned session, any backend CLI: keep its normal tools, unrerouted.
## Silence with a clean exit is the allow a *-native client reads, same as every
## other allow path in this estate's hooks. TodoWrite alone is decided below for every
## *-native session, spawned or not, by whether CheckList is offered to it (human-owner).
if [ "$1" != TodoWrite ] && { [ -n "${MDAT_SPAWN_SESSION_ID:-}" ] || [ -n "${MDAT_SPAWN_AGENT:-}" ] ; } ; then
	exit 0
fi

## The Slack-backed twins reach a person only over Slack, so they are pointed to only
## where this workspace has Slack set up: the two settings the owner setup's `slack`
## check requires (--owner-setup-slack: SLACK_CHANNEL_MAGIC_TEAM, SLACK_CHANNEL_HUMAN_OWNER)
## and the team bot token the twins are sent through, each read as the settings reader
## reads it, the last line of its key, by builtins alone. Anywhere else this hook makes
## no decision on them: silence with a clean exit, and the client handles the call as it
## would with no hook.
case "$1" in
AskUserQuestion|PushNotification)
	hookSettings="${CLAUDE_PROJECT_DIR:-$PWD}/.local/.agents/magic-team.agent.env"
	[ -f "$hookSettings" ] && [ -r "$hookSettings" ] || exit 0
	hookTeam="" hookOwner="" hookBot=""
	while IFS= read -r hookLine || [ -n "$hookLine" ] ; do
		case "$hookLine" in
			SLACK_CHANNEL_MAGIC_TEAM=*) hookTeam="${hookLine#*=}" ;;
			SLACK_CHANNEL_HUMAN_OWNER=*) hookOwner="${hookLine#*=}" ;;
			SLACK_BOT_TOKEN=*) hookBot="${hookLine#*=}" ;;
		esac
	done < "$hookSettings"
	[ -n "$hookTeam" ] && [ -n "$hookOwner" ] && [ -n "$hookBot" ] || exit 0
;;
esac

## CheckList is pointed to only where it is offered to this session, spawned or not: where the
## harness knows the member and the place of its list. The harness is asked that itself
## (--intern-checklist-place, AgentsHarnessCheckListPlace; CheckList is listed on the MCP
## floor whether or not a place is known, and refuses at execution where there is none),
## with the session id this call's input names, this session's own environment, and the
## workspace and tooling the myx.distro server runs for, so the member is resolved from the
## skillset folder that server reads; nothing is run, logged or written by the asking. Anywhere
## else -- no session id, no member known, no tooling to ask -- this hook makes no decision on
## TodoWrite, and the client's own tool works.
case "$1" in
TodoWrite)
	hookWs="${MMDAPP:-${CLAUDE_PROJECT_DIR:-}}"
	hookWs="${hookWs%/}"
	[ -n "$hookWs" ] && [ -d "$hookWs/.local" ] || exit 0
	hookOrigin="${MDLT_ORIGIN:-$hookWs/.local}"
	[ -f "$hookOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" ] || exit 0
	hookSession="$( printf '%s\n' "$hookInput" | LC_ALL=C awk -v path=session_id -v optional=1 -f "$hookOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessJsonField.awk" 2> /dev/null )" || hookSession=""
	[ -n "$hookSession" ] || exit 0
	hookAnswer="$( MMDAPP="$hookWs" MDLT_ORIGIN="$hookOrigin" CLAUDE_CODE_SESSION_ID="$hookSession" \
		"${BASH:-bash}" "$hookOrigin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" --intern-checklist-place < /dev/null 2> /dev/null )" || hookAnswer=""
	case "$hookAnswer" in
		'CHECKLIST-PLACE: '*) ;;
		*) exit 0 ;;
	esac
;;
esac

## The one document a PreToolUse hook answers with. $1 is the reason, and the reason is
## the only thing that differs between the tools below.
denyWith(){
	printf '{\n'
	printf '\t"hookSpecificOutput": {\n'
	printf '\t\t"hookEventName": "PreToolUse",\n'
	printf '\t\t"permissionDecision": "deny",\n'
	printf '\t\t"permissionDecisionReason": "%s"\n' "$1"
	printf '\t}\n'
	printf '}\n'
	exit 0
}

case "$1" in

Bash)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__execute -- it runs a shell script with the workspace context already established"
;;

AskUserQuestion)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__AskQuestion (mcp__myx_distro__ConfirmReadback for a readback, mcp__myx_distro__EscalateDecision for a decision, mcp__myx_distro__RequestPermission for a permission) -- it asks the person over Slack and records the question as a pending reply, so an answer can resume this work after this session has gone, which a question asked in this terminal cannot"
;;

Read)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Read -- it reads the file with the workspace context established, which is where the paths in this estate resolve"
;;

Write)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Write -- it writes the file with the workspace context established, which is where the paths in this estate resolve"
;;

Edit)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Edit -- it edits the file with the workspace context established, which is where the paths in this estate resolve"
;;

Glob)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Glob -- it matches inside the workspace context established, so the roots it walks are the ones this estate grants"
;;

Grep)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Grep -- it searches inside the workspace context established, so the roots it walks are the ones this estate grants"
;;

WebFetch)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__WebFetch -- one fetch path for this estate, under its own settings, rather than the client own"
;;

WebSearch)
	## The client's own WebSearch runs; an install that still carries this entry lets it through.
	exit 0
;;

PushNotification)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__PushNotification -- one notification path for this estate, under its own team identity, rather than the client own"
;;

Monitor)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__Wait -- in this estate Wait replaces Monitor: a process started detached through mcp__myx_distro__execute, a file, a thread are each a Wait source, watched with the session state of this estate"
;;

TodoWrite)
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__CheckList -- the checklist of session tasks of this session, with the same input, kept in the session state of this estate rather than the client own"
;;

claude_ai)
	## Every claude.ai connector tool arrives under this one name; which connector it is
	## comes from the tool_name of the input, read by builtins alone.
	hookCalled="${hookInput#*\"tool_name\"}"
	hookCalled="${hookCalled#*\"}"
	hookCalled="${hookCalled%%\"*}"
	case "$hookCalled" in
		mcp__claude_ai_*[Ss]lack*) hookTwin="DistroAgentsSlack" ;;
		mcp__claude_ai_*[Aa]tlassian*|mcp__claude_ai_*[Jj]ira*|mcp__claude_ai_*[Cc]onfluence*) hookTwin="DistroAgentsAtlassian" ;;
		mcp__claude_ai_*[Tt]rello*) hookTwin="DistroAgentsTrello" ;;
		mcp__claude_ai_*[Gg]mail*|mcp__claude_ai_*[Mm]ail*) hookTwin="DistroAgentsMail" ;;
		mcp__claude_ai_*[Gg]oogle*|mcp__claude_ai_*[Cc]alendar*|mcp__claude_ai_*[Dd]rive*) hookTwin="DistroAgentsGoogle" ;;
		*) hookTwin="" ;;
	esac
	if [ -n "$hookTwin" ] ; then
		denyWith "use the myx.distro MCP instead, method mcp__myx_distro__$hookTwin -- this estate own tool for that platform, under its own team identity and settings"
	fi
	denyWith "this tool is not reachable from this session, and this estate serves no tool for that platform over the myx.distro MCP. Report that rather than retrying."
;;

*)
	denyWith "this hook was installed for a tool it carries no reroute for, so it cannot say where to go instead. The installed PreToolUse entry and this script disagree. Report that rather than retrying: a hook that cannot decide refuses here, because one that emits nothing would read as permission."
;;

esac
