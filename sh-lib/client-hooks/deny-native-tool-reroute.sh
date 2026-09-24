#!/bin/bash
## deny-native-tool-reroute.sh -- the PreToolUse hook that routes a *-native agent CLI
## off its own built-in tools and onto this estate's MCP tooling. A REAL SCRIPT: it is
## installed by copying, it runs exactly as it stands here, and nothing is substituted
## into it. What it refuses and what it answers with are below, in full.
##
## The tool being decided arrives as $1, from the PreToolUse entry's own command string
## in .claude/settings.json -- one entry per matcher, each naming its own tool. That
## string is run by a shell, so the name reaches here as an ordinary argument.
##
## Every reroute here is unconditional and payload-blind: the tool is denied whatever
## arguments it was called with, so stdin is drained and never looked at. The drain is
## there so the client does not see a broken pipe. The conditional, path-scoped Read
## guard is deny-memory-md-read.sh, a separate script, because that one has to read the
## payload and it has an allow path. NOTHING HERE ALLOWS ANYTHING.
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

cat >/dev/null

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
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__AskUserQuestion -- it asks the person over Slack and records the question as a pending reply, so an answer can resume this work after this session has gone, which a question asked in this terminal cannot"
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
	denyWith "use the myx.distro MCP instead, method mcp__myx_distro__WebSearch -- one search path for this estate, under its own settings, rather than the client own"
;;

*)
	denyWith "this hook was installed for a tool it carries no reroute for, so it cannot say where to go instead. The installed PreToolUse entry and this script disagree. Report that rather than retrying: a hook that cannot decide refuses here, because one that emits nothing would read as permission."
;;

esac
