#!/usr/bin/env bash
## The PreToolUse hook client-hooks/deny-native-tool-reroute.sh points the client's own way to ask
## or tell the person (AskUserQuestion, PushNotification) to the Slack-backed twins only where this
## workspace has Slack set up: the two settings the owner setup's `slack` check requires
## (SLACK_CHANNEL_MAGIC_TEAM, SLACK_CHANNEL_HUMAN_OWNER) and the team bot token the twins are sent
## through, each read as the settings reader reads it, the last line of its key. Held here:
##   1. Slack set up: both are refused, each naming its twin, as before; a spawned session is let
##      through;
##   2. not set up -- no settings file, the bot token alone, a channel emptied by a later line or
##      only in a comment, the channels with no bot token -- the hook makes no decision: nothing on
##      stdout, nothing on stderr, rc 0, which a *-native client and our own harness both read as
##      no decision; every other reroute still refuses there;
##   3. a call the grants allow is answered allow by allow-granted-native-tool.sh with Slack set up
##      and without it, and the reroute hook does not refuse it; a call not allowed gets no answer
##      without Slack, never allow.
## And, beside the gate: a native TodoWrite is refused, naming CheckList, with Slack set up and
## without it, in a session CheckList is offered to -- its member and the place of its list known
## to the harness, the session id read from the call's input, spawned or not; a session it is
## not offered to (no member known, no session id), spawned or not, gets no decision, and the
## native tool works.
## Red before the fix: the bot token alone, a channel emptied by a later line and a channel only in
## a comment were refused.
## Offline: HOME, the workspace and every registry are this rig own; nothing is requested.
## Every tool_input object is built by rigObj and passed in a variable: a literal {a,b} inside
## "$( )" is brace-expanded by bash 3.2 into several words.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigReroute="$rigHere/client-hooks/deny-native-tool-reroute.sh"
rigAllow="$rigHere/client-hooks/allow-granted-native-tool.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigReroute" "$rigAllow" "$rigHere/AgentsTools.Grants.include" "$rigHere/AgentsTools.ClientToolPolicy.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClientHookSlackGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$#" -ne 3 ] ; then
		printf '  FAIL  %s\n        the assertion took %s arguments, not 3\n' "$1" "$#" ; rigFail=$(( rigFail + 1 )) ; return 0
	fi
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## rig-member: a write grant on granted/; nothing on others/.
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/granted" "$rigTmp/others"
printf '%s\t%s\t%s\t%s\t%s\n' ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
printf 'rig-member:ws:workspace:Edit(/%s/granted/**)\n' "$rigTmp" > "$rigWs/.local/agents/permissions.registry"
for rigOne in granted/a.txt others/a.txt ; do printf 'rig-seed\n' > "$rigTmp/$rigOne" ; done

## The team settings file of the rig workspace, one line per argument; none at all for no file.
rigSlack(){ ## line...
	rm -f "$rigWs/.local/.agents/magic-team.agent.env"
	[ "$#" -eq 0 ] || printf '%s\n' "$@" > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigSlackSet(){
	rigSlack "SLACK_CHANNEL_MAGIC_TEAM=Crigteam" "SLACK_CHANNEL_HUMAN_OWNER=Urigowner" "SLACK_BOT_TOKEN=rig-not-a-token" "$@"
}

rigObj(){ ## key, raw JSON string text, ... -- one object of string members, the text not escaped again
	local objOut="" objSep=""
	while [ "$#" -ge 2 ] ; do
		objOut="$objOut$objSep\"$1\":\"$2\"" ; objSep=","
		shift 2
	done
	printf '{%s}' "$objOut"
}
rigPayload(){ ## tool, tool_input object -- one PreToolUse payload
	printf '{"session_id":"s-rig","transcript_path":"%s/t.jsonl","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' "$rigTmp" "$rigTmp/granted" "$1" "$2"
}
## What a hook answered: none (nothing on stdout or stderr, rc 0), allow, deny:<the MCP method
## its reason names, else the reason>, or other:<all of it>.
rigVerdict(){ ## rc, stdout, stderr file
	if [ "$1" = 0 ] && [ -z "$2" ] && [ ! -s "$3" ] ; then printf none ; return 0 ; fi
	case "$1:$2" in
		'0:'*'"permissionDecision": "allow"'*) printf allow ;;
		'0:'*'"permissionDecision": "deny"'*)
			local verdictWhy
			verdictWhy="$( printf '%s' "$2" | LC_ALL=C sed -n 's/.*"permissionDecisionReason": "\(.*\)"$/\1/p' )"
			case "$verdictWhy" in
				*'method mcp__myx_distro__'*) verdictWhy="${verdictWhy#*method mcp__myx_distro__}" ; verdictWhy="${verdictWhy%%[!A-Za-z]*}" ;;
			esac
			printf 'deny:%s' "$verdictWhy"
		;;
		*) printf 'other:rc=%s out=%s err=%s' "$1" "$2" "$( cat "$3" )" ;;
	esac
}
rigRerouteRun(){ ## tool, tool_input object, [extra env]...
	local runTool="$1" runInput="$2" runRc=0 runOut ; shift 2
	runOut="$( rigPayload "$runTool" "$runInput" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin CLAUDE_PROJECT_DIR="$rigWs" \
		"$@" bash "$rigReroute" "$runTool" 2> "$rigTmp/reroute.err" )" || runRc=$?
	rigVerdict "$runRc" "$runOut" "$rigTmp/reroute.err"
}
rigAllowRun(){ ## tool, tool_input object -- as the spawned rig-member
	local runRc=0 runOut
	runOut="$( rigPayload "$1" "$2" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig bash "$rigAllow" 2> "$rigTmp/allow.err" )" || runRc=$?
	rigVerdict "$runRc" "$runOut" "$rigTmp/allow.err"
}
rigAsk="$( rigObj question rig )"
rigPush="$( rigObj message rig )"
rigBoth(){ ## [extra env]... -- the verdicts on AskUserQuestion and PushNotification
	printf '%s|%s' "$( rigRerouteRun AskUserQuestion "$rigAsk" "$@" )" "$( rigRerouteRun PushNotification "$rigPush" "$@" )"
}

echo "-- 1. Slack set up: the redirect judges, as before --"
rigSlackSet
rigAssert "both refused, each naming its twin" "$( rigBoth )" "deny:AskQuestion|deny:PushNotification"
rigSlack "# the team" "SLACK_BOT_TOKEN=rig-not-a-token" "SLACK_CHANNEL_HUMAN_OWNER=Urigowner" "SLACK_CHANNEL_MAGIC_TEAM=Crigteam"
rigAssert "in any order, beside a comment" "$( rigBoth )" "deny:AskQuestion|deny:PushNotification"
rigSlackSet "SLACK_CHANNEL_HUMAN_OWNER=Urigother"
rigAssert "a key given twice, the last one set" "$( rigBoth )" "deny:AskQuestion|deny:PushNotification"
rigSlackSet
rigAssert "control: a spawned session is let through" "$( rigBoth MDAT_SPAWN_AGENT=rig-member )" "none|none"

echo "-- 2. Slack not set up: no decision at all --"
rigSlack
rigAssert "no settings file"                   "$( rigBoth )" "none|none"
rigSlack "SLACK_BOT_TOKEN=rig-not-a-token"
rigAssert "the bot token alone, no channel"    "$( rigBoth )" "none|none"
rigSlackSet "SLACK_CHANNEL_HUMAN_OWNER="
rigAssert "the owner channel emptied by a later line" "$( rigBoth )" "none|none"
rigSlack "#SLACK_CHANNEL_MAGIC_TEAM=Crigteam" "SLACK_CHANNEL_HUMAN_OWNER=Urigowner" "SLACK_BOT_TOKEN=rig-not-a-token"
rigAssert "the team channel only in a comment" "$( rigBoth )" "none|none"
rigSlack "SLACK_CHANNEL_MAGIC_TEAM=Crigteam" "SLACK_CHANNEL_HUMAN_OWNER=Urigowner"
rigAssert "the channels with no bot token"     "$( rigBoth )" "none|none"
rigSlack "SLACK_CHANNEL_MAGIC_TEAM=Crigteam" "SLACK_CHANNEL_HUMAN_OWNER=Urigowner" "SLACK_BOT_TOKEN="
rigAssert "the channels with an empty bot token" "$( rigBoth )" "none|none"
rigSlack "SLACK_BOT_TOKEN=rig-not-a-token"
rigOthers="$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/AgentsTools.ClientToolPolicy.include" ; AgentsToolsClientToolPolicyRerouteToolNames' )" \
	|| rigRefuse "the reroute tool names could not be read"
rigOtherAll=0 rigOtherDeny=0
while IFS= read -r rigOne ; do
	case "$rigOne" in ''|AskUserQuestion|PushNotification|TodoWrite) continue ;; esac
	rigOtherAll=$(( rigOtherAll + 1 ))
	case "$( rigRerouteRun "$rigOne" "$( rigObj file_path "$rigTmp/granted/a.txt" )" )" in deny:*) rigOtherDeny=$(( rigOtherDeny + 1 )) ;; esac
done <<< "$rigOthers"
rigAssert "every other reroute still refuses there" "$rigOtherDeny of $rigOtherAll" "$rigOtherAll of $rigOtherAll"
rigAssert "control: there are other reroutes"  "$( [ "$rigOtherAll" -gt 0 ] && printf yes || printf no )" yes

echo "-- 2b. a native TodoWrite goes to CheckList only where CheckList is offered, outside the Slack gate --"
## A tooled session: the member a root session is served as, magic-coordinator, in the members
## index of the workspace the server runs for, and the tooling found by MDLT_ORIGIN.
rigTodo="$( rigObj todos rig )"
rigTooled(){ ## present|absent -- the root session's member, and rig-member, in the rig workspace's members index
	rm -rf "$rigWs/.local/agents/members"
	[ "$1" = present ] || return 0
	for rigOne in magic-coordinator rig-member ; do
		mkdir -p "$rigWs/.local/agents/members/$rigOne" && printf 'rig\n' > "$rigWs/.local/agents/members/$rigOne/$rigOne.basic.md"
	done
}
rigNoSessionRun(){ ## [extra env]... -- a TodoWrite call whose input names no session
	local runRc=0 runOut
	runOut="$( printf '{"hook_event_name":"PreToolUse","tool_name":"TodoWrite","tool_input":%s}' "$rigTodo" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin CLAUDE_PROJECT_DIR="$rigWs" \
		"$@" bash "$rigReroute" TodoWrite 2> "$rigTmp/reroute.err" )" || runRc=$?
	rigVerdict "$runRc" "$runOut" "$rigTmp/reroute.err"
}
rigTooled present
rigAssert "a tooled session without Slack: refused, naming CheckList" "$( rigRerouteRun TodoWrite "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" )" "deny:CheckList"
rigSlackSet
rigAssert "a tooled session with Slack: refused, naming CheckList" "$( rigRerouteRun TodoWrite "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" )" "deny:CheckList"
rigAssert "a spawned claude-native session whose rule resolves is redirected too" "$( rigRerouteRun TodoWrite "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig )" "deny:CheckList"
rigAssert "a spawned session whose member is not known: no decision" "$( rigRerouteRun TodoWrite "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_AGENT=rig-unknown MDAT_SPAWN_SESSION_ID=s-rig )" "none"
rigAssert "control: the other reroutes still let a spawned session through" "$( rigRerouteRun Grep "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig )" "none"
rigAssert "a session whose input names no session id: no decision, the native tool works" "$( rigNoSessionRun MDLT_ORIGIN="$MDLT_ORIGIN" )" "none"
rigTooled absent
rigAssert "a session whose member is not known: no decision, the native tool works" "$( rigRerouteRun TodoWrite "$rigTodo" MDLT_ORIGIN="$MDLT_ORIGIN" )" "none"
rigAssert "a workspace with no tooling to ask: no decision" "$( rigRerouteRun TodoWrite "$rigTodo" )" "none"
rigAssert "nothing was written into the rig workspace by any of them" "$( find "$rigWs" -name '*.checklist.md' | LC_ALL=C grep -c . )" "0"
rigSlack "SLACK_BOT_TOKEN=rig-not-a-token"

echo "-- 3. allowed by the grants: allow, with Slack and without --"
rigIn="$( rigObj file_path "$rigTmp/granted/a.txt" old_string a new_string b )"
rigSlackSet
rigAssert "Slack set up: an Edit granted is allowed" "$( rigAllowRun Edit "$rigIn" )" allow
rigAssert "and the reroute hook does not refuse it" "$( rigRerouteRun Edit "$rigIn" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig )" none
rigSlack
rigAssert "no Slack: the same Edit is allowed" "$( rigAllowRun Edit "$rigIn" )" allow
rigAssert "and the reroute hook does not refuse it" "$( rigRerouteRun Edit "$rigIn" MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig )" none
rigIn="$( rigObj file_path "$rigTmp/others/a.txt" old_string a new_string b )"
rigAssert "no Slack: an Edit not granted gets no answer, never allow" "$( rigAllowRun Edit "$rigIn" )" none

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLIENT HOOK SLACK GATE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_HOOK_SLACK_GATE: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
