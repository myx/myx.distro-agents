#!/usr/bin/env bash
## Behavioural check on the team permission model (AgentsTools.PermissionHolds.include):
## the layers a member holds, no approving what you don't hold, routing up the chain,
## passing a permission on within its limits, a task's permission set, task expiry,
## per-member harness write roots, and an allow-read row that reads but never writes. Offline: a Slack-shaped fake curl is first on PATH,
## and everything runs in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

rigTmp="$( mktemp -d -t AgentsPermissionHoldsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The rig workspace: a coworking session rig-cow with the coordinator, the developer
## (spawned by the coordinator) and the tester; a task item; standing rows.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-cow" "$rigData/board/running" "$rigData/board/processed" \
	"$rigWs/DEV" "$rigWs/ELSE" "$rigWs/KEEP"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
{
	printf 'magic-developer:ws:workspace:Edit(/%s/DEV/**)\n' "$rigWs"
	printf 'keeper-myx:ws:namespace:Edit(/%s/KEEP/**)\n' "$rigWs"
	printf 'keeper-myx:ws:tool:WebFetch:https://docs.rig.example/*\n'
	printf 'magic-architect:ws:tool:WebSearch\n'
} > "$rigWs/.local/agents/permissions.registry"
## Running sessions: a session grant ends when its session closes (AgentsToolsGrantsSessionEnded).
rigSpawnRecord(){ ## spawn id, owner, parent session id
	printf -- '---\nsession-id: rig-cow\nspawn-id: %s\n%sowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "${3:+parent-session-id: $3$'\n'}" "$2" > "$rigWs/.local/agents/spawned/rig-cow/$1.md"
}
rigSpawnRecord rig-coord magic-coordinator ""
rigSpawnRecord rig-dev magic-developer rig-coord
rigSpawnRecord rig-tester magic-tester rig-coord
printf -- '---\nstatus: task\nowner: magic-tester\n---\n\n# Task\n' > "$rigData/board/running/task-rig.md"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## One team operation as RIG_OP_AGENT in session RIG_OP_SESSION; out and err kept.
RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOp(){
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
## An in-context helper (no operation of its own) as a script for --intern-mcp-execute, which
## runs it inside the tool's own set-up context: its include, then the call with these arguments.
rigHelperScript(){ ## include, function, arguments...
	printf '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/%s"\n' "$1"
	printf '%s' "$2" ; shift 2
	[ $# -eq 0 ] || printf ' %q' "$@"
	printf '\n'
}
rigHolds(){ ## member, tool, target, [session]
	rigOp --intern-op-permission-holds "$1" "$2" "$3" ${4:+--session-id "$4"}
	head -1 "$rigTmp/op.out"
}
rigRefusal(){ ## member, session, tool, target
	rigOp --intern-op-permission-refusal-log "$1" --session-id "$2" --tool "$3" --target "$4" --reason rig
	LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/op.out" | head -1
}
rigGrantRead(){ ## member, session, tool, target
	rigOp --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1
}
rigGrantOpen(){ ## approver, session, refusal id, kind, [task]; prints "<rc> <first GRANT/NOT-HOLDS line>"
	local openRc=0
	rigOp --intern-op-permission-grant-open "$1" --session-id "$2" --refusal-id "$3" --kind "$4" ${5:+--task "$5"} || openRc=$?
	printf '%s %s' "$openRc" "$( LC_ALL=C grep -m1 -E '^(GRANT|NOT-HOLDS):' "$rigTmp/op.out" | LC_ALL=C awk '{ print $1 ; }' )"
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG"
}
## A permission escalation record for one refusal, addressed to the coordinator, as AskUserQuestion leaves it.
rigPermissionAsk(){ ## owner, session, refusal id
	printf '# Permission\n\nMay I?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open "$1" --to CRIG00001 --session-id "$2" --kind permission --address-to magic-coordinator \
		--refusal-id "$3" --channel CRIG00001 --question-ts 1700000000.000001 --thread-ts 1700000000.000001 --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2>/dev/null )
}

echo "-- (a) the floor and (b) per-member defaults, files and tools --"
rigAssert "a team tool is the floor"                       "$( rigHolds magic-tester SendMessage '' )" "HOLDS floor"
rigAssert "the team scratch is the floor"                  "$( rigHolds magic-tester Write "$rigWs/.local/temp/team/x" )" "HOLDS floor"
rigAssert "its own temp is the floor"                      "$( rigHolds magic-tester Edit "$rigWs/.local/temp/member/magic-tester/x" )" "HOLDS floor"
rigAssert "so is all of .local/temp, another member's temp included" "$( rigHolds magic-tester Edit "$rigWs/.local/temp/member/magic-developer/x" )" "HOLDS floor"
rigAssert "the workspace source is in no member's floor"   "$( rigHolds magic-tester Read "$rigWs/source/a.txt" )" "NOT-HOLDS"
rigAssert "a member folder is read by the floor"           "$( rigHolds magic-tester Read "$( cd "$MDAT_SKILLSET_ROOT/magic-developer" && pwd -P )/magic-developer.basic.md" )" "HOLDS floor"
rigAssert "a keeper's own domain is standing rwe"          "$( rigHolds keeper-myx Edit "$rigWs/KEEP/a/b.txt" ):$( rigHolds keeper-myx Execute "$rigWs/KEEP/run.sh" ):$( rigHolds keeper-myx Read "$rigWs/KEEP/.env" )" "HOLDS standing:HOLDS standing:HOLDS standing"
rigAssert "nobody else's domain is held by it"             "$( rigHolds keeper-myx Write "$rigWs/DEV/x" )" "NOT-HOLDS"
rigAssert "a .. out of a domain is never covered"          "$( rigHolds keeper-myx Write "$rigWs/KEEP/../ELSE/x" )" "NOT-HOLDS"
rigAssert "a standing tool row holds its prefix"           "$( rigHolds keeper-myx WebFetch https://docs.rig.example/a/b )" "HOLDS standing"
## Rows are machine-wide (every workspace HOME's pointers name), and magic-architect holds any
## URL built in: the prefix row is a keeper's, read off the rig's own rows alone, under a rig HOME.
rigAssert "and not beyond it"                              "$( HOME="$rigTmp" rigHolds keeper-myx WebFetch https://other.rig.example/ )" "NOT-HOLDS"
rigAssert "a bare tool row holds any target"               "$( rigHolds magic-architect WebSearch 'any query' )" "HOLDS standing"
rigAssert "another member does not hold WebFetch"          "$( rigHolds magic-developer WebFetch https://docs.rig.example/a )" "NOT-HOLDS"
rigAssert "cred starts with no member"                     "$( rigHolds magic-architect cred prod-db ):$( rigHolds magic-coordinator spend 100usd )" "NOT-HOLDS:NOT-HOLDS"
rigAssert "the human-owner holds everything"               "$( rigHolds human-owner cred prod-db ):$( rigHolds URIGOWNER Write /anywhere )" "HOLDS human-owner:HOLDS human-owner"
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionHoldersPrint Write "$rigWs/DEV/a" --session-id rig-tester | rigOp --intern-mcp-execute
rigAssert "holders: participants that hold it, then the human-owner" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/op.out" )" "HOLDER: magic-developer standing|HOLDER: human-owner human-owner|"

echo "-- rule 1: the coordinator approving what it does not hold --"
rigIdDev="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/a.txt" )"
[ -n "$rigIdDev" ] || rigRefuse "no refusal could be recorded"
rigAssert "grant-open by a non-holder is refused, rc 3"   "$( rigGrantOpen magic-coordinator rig-tester "$rigIdDev" session )" "3 NOT-HOLDS:"
rigAssert "naming the holder up the chain"                 "$( rigHas "$rigTmp/op.out" 'HOLDERS: magic-developer human-owner' )" yes
rigAssert "and nothing is granted"                         "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/a.txt" )" ""
rigAssert "a holder's approval is granted"                 "$( rigGrantOpen magic-developer rig-tester "$rigIdDev" session )" "0 GRANT:"
rigAssert "and admits the call"                            "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/a.txt" )" session
rigIdHuman="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/h.txt" )"
rigAssert "the human-owner's account approves anything"    "$( rigGrantOpen URIGOWNER rig-tester "$rigIdHuman" once )" "0 GRANT:"
rigIdHuman2="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/h2.txt" )"
rigAssert "and so does human-owner by name"                "$( rigGrantOpen human-owner rig-tester "$rigIdHuman2" once )" "0 GRANT:"

echo "-- rule 1 on the escalation answer: routed to a holder participant --"
rigIdR="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/r.txt" )"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdR" )"
[ -n "$rigPend" ] || rigRefuse "no escalation record could be opened"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-session
rigAssert "the coordinator's allow is not applied"         "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend rerouted" )" yes
rigAssert "it is re-addressed to the holder"               "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to )" magic-developer
rigAssert "and stays open"                                 "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" status )" reply-pending
rigAssert "nothing was granted"                            "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/r.txt" )" ""
RIG_OP_AGENT=magic-developer RIG_OP_SESSION=rig-dev rigOp --member-escalation-answer magic-developer "$rigPend" allow-session
rigAssert "the holder's answer is applied"                 "$( rigHas "$rigTmp/op.out" "GRANT: session $rigIdR" )" yes
rigAssert "and the call is admitted"                       "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/r.txt" )" session

echo "-- no holder among the participants: up to the human-owner through the forward --"
rigPosts="$( rigCalls chat.postMessage )"
rigIdE="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/e.txt" )"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdE" )"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-once
rigAssert "re-addressed to the human-owner"                "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to )" human-owner
rigAssert "through the existing forward"                   "$( [ -n "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" forward-ts )" ] && printf yes || printf no )" yes
rigAssert "one post was made for it"                       "$(( $( rigCalls chat.postMessage ) - rigPosts >= 1 ))" 1

echo "-- a cred or spend request goes to the human-owner --"
rigIdC="$( rigRefusal magic-tester rig-tester cred prod-db-password )"
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionHoldersPrint cred prod-db-password --session-id rig-tester | rigOp --intern-mcp-execute
rigAssert "nobody in the session holds a cred"            "$( LC_ALL=C tr '\n' '|' < "$rigTmp/op.out" )" "HOLDER: human-owner human-owner|"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdC" )"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-session
rigAssert "the coordinator's allow goes to the human-owner" "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to )" human-owner
rigIdS="$( rigRefusal magic-tester rig-tester spend 50usd )"
rigAssert "a spend is approved by the human-owner only"   "$( rigGrantOpen magic-architect rig-tester "$rigIdS" once ):$( rigGrantOpen URIGOWNER rig-tester "$rigIdS" once )" "3 NOT-HOLDS::0 GRANT:"

echo "-- passing a permission on, within its limits --"
RIG_OP_AGENT=magic-developer RIG_OP_SESSION=rig-dev
rigOp --member-permission-pass magic-developer --to magic-tester --tool Write --target "$rigWs/DEV/sub/**" --kind session
rigAssert "a holder passes part of its own to a participant" "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/op.out" )" session
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigAssert "the receiver is admitted under it"             "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/sub/x/y.txt" )" session
rigAssert "and nowhere else"                               "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/z.txt" )" ""
RIG_OP_AGENT=magic-developer RIG_OP_SESSION=rig-dev
rigOp --member-permission-pass magic-developer --to magic-tester --tool Write --target "$rigWs/**" --kind session
rigAssert "more than the passer holds is refused"         "$( rigHas "$rigTmp/op.err" 'does not hold' ):$( LC_ALL=C grep -c '^GRANT:' "$rigTmp/op.out" )" "yes:0"
rigOp --member-permission-pass magic-developer --to magic-frontender --tool Write --target "$rigWs/DEV/f/**" --kind session
rigAssert "a non-participant is refused"                   "$( rigHas "$rigTmp/op.err" 'takes no part' )" yes
rigOp --member-permission-pass magic-developer --to magic-tester --tool Write --target "$rigWs/DEV/t/**" --kind task --task task-rig
rigAssert "a task pass is written"                         "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/op.out" )" task
RIG_OP_AGENT=magic-tester RIG_OP_SESSION=rig-tester
rigOp --member-permission-pass magic-tester --to magic-coordinator --tool Write --target "$rigWs/DEV/t/**" --kind session
rigAssert "a task grant does not pass on for the session" "$( rigHas "$rigTmp/op.err" 'only for task task-rig' )" yes
rigOp --member-permission-pass magic-tester --to magic-coordinator --tool Write --target "$rigWs/DEV/t/**" --kind task --task task-rig
rigAssert "but passes on for the same task"                "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/op.out" )" task
RIG_OP_AGENT=magic-developer
rigOp --member-permission-pass magic-tester --to magic-coordinator --tool Write --target "$rigWs/DEV/t/**" --kind once
rigAssert "nobody passes as another member"                "$( rigHas "$rigTmp/op.err" 'cannot act as magic-tester' )" yes
RIG_OP_AGENT="" RIG_OP_SESSION=""

echo "-- a task grant expires when its item closes --"
rigAssert "the task pass admits while the item is open"    "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/t/a.txt" )" task
rigIdT="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/task.txt" )"
rigAssert "a task grant from a refusal"                    "$( rigGrantOpen magic-developer rig-tester "$rigIdT" task task-rig )" "0 GRANT:"
rigAssert "admits while the item is open"                  "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/task.txt" )" task
mv "$rigData/board/running/task-rig.md" "$rigData/board/processed/task-rig.md"
rigAssert "and neither admits once it is processed"        "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/task.txt" ):$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/t/a.txt" )" ":"
rigAssert "nor can one be opened for a closed item"        "$( rigGrantOpen magic-developer rig-tester "$rigIdT" task task-rig )" "1 "
mv "$rigData/board/processed/task-rig.md" "$rigData/board/running/task-rig.md"

echo "-- the permission set: held entries, ONE ask for the extras, Decisions and grants --"
rigPosts="$( rigCalls chat.postMessage )"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
rigOp --magic-permission-set-request magic-coordinator task-rig --entry "Write:$rigWs/DEV/**" \
	--entry "WebFetch:https://api.rig.example/*" --entry "cred:rig-api-token" --scope task --session-id rig-cow
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigAssert "a held entry is said held, by its holder"      "$( rigHas "$rigTmp/op.out" "HELD: Write:$rigWs/DEV/** by magic-developer standing" )" yes
rigAssert "the extras are said"                            "$( LC_ALL=C grep -c '^EXTRA: ' "$rigTmp/op.out" )" 2
rigSetId="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
rigAssert "ONE ask is posted for them"                     "$(( $( rigCalls chat.postMessage ) - rigPosts ))" 1
rigAssert "a permission-set escalation to the human-owner" "$( rigField "$rigWs/.local/agents/pending/$rigSetId.md" kind ):$( rigField "$rigWs/.local/agents/pending/$rigSetId.md" address-to )" "permission-set:human-owner"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigSetId" allow-set
rigAssert "the asking coordinator cannot approve its own set" "$( rigHas "$rigTmp/op.err" 'cannot answer it' ):$( rigField "$rigWs/.local/agents/pending/$rigSetId.md" status )" "yes:reply-pending"
RIG_OP_SESSION=rig-human rigOp --member-escalation-answer human-owner "$rigSetId" allow-set
rigAssert "the human-owner's allow-set is applied"         "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigSetId answered" ):$( rigHas "$rigTmp/op.out" 'GRANT: set ' )" "yes:yes"
rigAssert "the set is recorded on the item's Decisions"    "$( rigHas "$rigData/board/running/task-rig.md" 'permission set approved for the task' )" yes
rigAssert "and as its allows, for a later dispatch"        "$( rigHas "$rigData/board/running/task-rig.md" 'allows: task:WebFetch:https%3A//api.rig.example/*:human-owner:' )" yes
rigAssert "every participant holds the extras now"         "$( rigGrantRead magic-tester rig-tester WebFetch https://api.rig.example/v1 ):$( rigGrantRead magic-developer rig-dev cred rig-api-token )" "task:task"
rigAssert "the held entry was not granted to others"       "$( rigGrantRead magic-tester rig-tester Write "$rigWs/DEV/q.txt" )" ""

echo "-- a spawn gets its defaults and the dispatch's approved extras; a planned allow by a non-holder is ignored --"
printf -- '---\nstatus: dispatch-started\nowner: magic-frontender\nsession-id: rig-new\ntracks: task-rig\nallows: session:Write:%s:magic-coordinator:20261009T0000Z,session:Write:%s:magic-developer:20261009T0000Z\n---\n\n# Dispatch\n' \
	"$rigWs/ELSE/p.txt" "$rigWs/DEV/p.txt" > "$rigData/board/running/dispatch-rig-new.md"
rigAssert "the tracked item's approved set reaches the spawn" "$( rigGrantRead magic-frontender rig-new WebFetch https://api.rig.example/v2 )" planned
rigAssert "a planned allow signed by a holder admits"      "$( rigGrantRead magic-frontender rig-new Write "$rigWs/DEV/p.txt" )" planned
rigAssert "one signed by a non-holder is ignored"          "$( rigGrantRead magic-frontender rig-new Write "$rigWs/ELSE/p.txt" )" ""
rigAssert "a standing tool needs no grant at all"          "$( rigGrantRead magic-architect rig-arch WebFetch https://docs.rig.example/x )" standing

echo "-- a routine allows its participants permissions for its run --"
## Two rig routines in a rig skillset: one the human-owner maintains, one he does not.
## Session rig-rcow runs the first (its starter's record names it, a joiner inherits it);
## rig-ncow runs the second.
rigSkillsReal="$MDAT_SKILLSET_ROOT"
rigSkills="$rigTmp/skills"
mkdir -p "$rigSkills/magic-tester" "$rigSkills/magic-developer" "$rigWs/.local/agents/spawned/rig-rcow" "$rigWs/.local/agents/spawned/rig-ncow"
printf -- '---\nexecutors: magic-tester\nmaintainers: magic-tester, human-owner\ninvitees: magic-developer\nallows: magic-tester:Edit:ROUT/**, executors:WebFetch:https%%3A//ex.rig.example/*, participants:Write:PART/**, magic-developer:cred:rig-token\n---\n# rig routine\n' \
	> "$rigSkills/magic-tester/magic-tester.rig-review.routine.md"
printf -- '---\nexecutors: magic-tester\nmaintainers: magic-developer\nallows: participants:cred:rig-secret, participants:Write:DEV/n/**, participants:Write:ELSE/**\n---\n# rig routine without the human-owner\n' \
	> "$rigSkills/magic-tester/magic-tester.rig-nohuman.routine.md"
printf -- '---\nsession-id: rig-rcow\nspawn-id: rig-rcow\nowner: magic-tester\nroutine: magic-tester.rig-review.routine.md\nstatus: spawn-started\n---\n' > "$rigWs/.local/agents/spawned/rig-rcow/rig-rcow.md"
printf -- '---\nsession-id: rig-rcow\nspawn-id: rig-r2\nparent-session-id: rig-rcow\nowner: magic-developer\nstatus: spawn-started\n---\n' > "$rigWs/.local/agents/spawned/rig-rcow/rig-r2.md"
printf -- '---\nsession-id: rig-ncow\nspawn-id: rig-ncow\nowner: magic-tester\nroutine: magic-tester.rig-nohuman.routine.md\nstatus: spawn-started\n---\n' > "$rigWs/.local/agents/spawned/rig-ncow/rig-ncow.md"
export MDAT_SKILLSET_ROOT="$rigSkills"
rigAssert "a member's routine allow holds in that routine's session" "$( rigHolds magic-tester Edit "$rigWs/ROUT/a.txt" rig-rcow )" "HOLDS routine magic-tester.rig-review.routine"
rigAssert "and not in another session"                     "$( rigHolds magic-tester Edit "$rigWs/ROUT/a.txt" rig-tester ):$( rigHolds magic-tester Edit "$rigWs/ROUT/a.txt" )" "NOT-HOLDS:NOT-HOLDS"
rigAssert "nor for another member"                         "$( rigHolds magic-developer Edit "$rigWs/ROUT/a.txt" rig-r2 )" "NOT-HOLDS"
rigAssert "executors: the routine's executor holds it"     "$( rigHolds magic-tester WebFetch https://ex.rig.example/x rig-rcow )" "HOLDS routine magic-tester.rig-review.routine"
rigAssert "and a participant who is no executor does not"  "$( rigHolds magic-developer WebFetch https://ex.rig.example/x rig-r2 )" "NOT-HOLDS"
rigAssert "participants: every participant, a joiner too" "$( rigHolds magic-tester Write "$rigWs/PART/a" rig-rcow ):$( rigHolds magic-developer Write "$rigWs/PART/a" rig-r2 )" "HOLDS routine magic-tester.rig-review.routine:HOLDS routine magic-tester.rig-review.routine"
rigAssert "but no member outside the session"             "$( rigHolds magic-frontender Write "$rigWs/PART/a" rig-rcow )" "NOT-HOLDS"
rigAssert "cred stands with human-owner as a maintainer"   "$( rigHolds magic-developer cred rig-token rig-r2 )" "HOLDS routine magic-tester.rig-review.routine"
rigAssert "the session's grant-read admits it as standing" "$( rigGrantRead magic-tester rig-rcow Edit "$rigWs/ROUT/b.txt" )" standing
rigAssert "cred without human-owner as maintainer is ignored" "$( rigHolds magic-tester cred rig-secret rig-ncow )" "NOT-HOLDS"
rigAssert "and said on stderr"                             "$( rigHas "$rigTmp/op.err" 'needs human-owner among its maintainers' )" yes
rigAssert "an entry a maintainer holds stands without him" "$( rigHolds magic-tester Write "$rigWs/DEV/n/a" rig-ncow )" "HOLDS routine magic-tester.rig-nohuman.routine"
rigAssert "one no maintainer holds is ignored"             "$( rigHolds magic-tester Write "$rigWs/ELSE/a" rig-ncow ):$( rigHas "$rigTmp/op.err" 'none of its maintainers holds it' )" "NOT-HOLDS:yes"
RIG_OP_AGENT=magic-tester RIG_OP_SESSION=rig-rcow
rigOp --member-permission-pass magic-tester --to magic-developer --tool Edit --target "$rigWs/ROUT/sub/**" --kind session
rigAssert "a routine permission passes on to a participant" "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/op.out" )" session
rigOp --member-permission-pass magic-tester --to magic-developer --tool Edit --target "$rigWs/**" --kind session
rigAssert "more than the routine allows is refused"        "$( rigHas "$rigTmp/op.err" 'does not hold' ):$( LC_ALL=C grep -c '^GRANT:' "$rigTmp/op.out" )" "yes:0"
rigOp --member-permission-pass magic-tester --to magic-developer --tool Edit --target "$rigWs/ROUT/t/**" --kind task --task task-rig
rigAssert "and it outlives the session for no task"        "$( rigHas "$rigTmp/op.err" 'only for this session' ):$( LC_ALL=C grep -c '^GRANT:' "$rigTmp/op.out" )" "yes:0"
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigAssert "the receiver holds what was passed, as passed"  "$( rigHolds magic-developer Edit "$rigWs/ROUT/sub/x" rig-r2 | LC_ALL=C awk '{ print $1, $2 ; }' )" "HOLDS passed"
export MDAT_SKILLSET_ROOT="$rigSkillsReal"

echo "-- harness write roots are per member --"
rigHarnessWrite(){ ## acting member (empty: none), path
	( cd "$rigWs" && printf '{"path":"%s","content":"x"}' "$2" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		MDAT_SPAWN_SESSION_ID=rig-harness RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" ${1:+MDAT_SPAWN_AGENT="$1"} \
		bash "$rigHarness" --intern-tool Write 2>/dev/null ) | LC_ALL=C awk 'NR == 1 { print $1 ; }'
}
. "$rigHere/AgentsTools.ClientAccessRoots.include"
rigAssert "the developer's own row is its write root"      "$( MMDAPP="$rigWs" AgentsToolsClientAccessGrantRoots magic-developer | LC_ALL=C grep -c -x -F "$rigWs/DEV" )" 1
rigAssert "and not the tester's"                           "$( MMDAPP="$rigWs" AgentsToolsClientAccessGrantRoots magic-tester | LC_ALL=C grep -c -x -F "$rigWs/DEV" )" 0
rigAssert "the developer's harness writes its domain"     "$( rigHarnessWrite magic-developer "$rigWs/DEV/h.txt" )" "OK:"
rigAssert "the tester's harness does not"                  "$( rigHarnessWrite magic-tester "$rigWs/DEV/h2.txt" )" "ERROR:"
rigAssert "a served call with no member keeps every row"   "$( rigHarnessWrite "" "$rigWs/DEV/h3.txt" )" "OK:"

echo "-- an allow-read row is read only: its member holds the read tools there, and nobody writes --"
mkdir -p "$rigWs/RONLY"
printf 'rig-ronly-seed\n' > "$rigWs/RONLY/r.txt"
printf 'rig-ronly-seed\n' > "$rigWs/ELSE/r.txt"
printf 'magic-tester:ws:workspace:Read(/%s/RONLY/**)\n' "$rigWs" >> "$rigWs/.local/agents/permissions.registry"
rigHarnessRead(){ ## acting member, path -- read, refused or other
	local readOut
	readOut="$( cd "$rigWs" && printf '{"path":"%s"}' "$2" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT \
		MDAT_SPAWN_SESSION_ID=rig-harness RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" ${1:+MDAT_SPAWN_AGENT="$1"} \
		bash "$rigHarness" --intern-tool Read 2>/dev/null )" || :
	case "$readOut" in
		*rig-ronly-seed*) printf read ;;
		*'not in the allowed access-root set'*) printf refused ;;
		*) printf other ;;
	esac
}
rigAssert "its member holds Read, Grep and Glob there, standing" \
	"$( rigHolds magic-tester Read "$rigWs/RONLY/r.txt" ):$( rigHolds magic-tester Grep "$rigWs/RONLY/r.txt" ):$( rigHolds magic-tester Glob "$rigWs/RONLY/**" )" "HOLDS standing:HOLDS standing:HOLDS standing"
rigAssert "and no Edit, Write or Execute there" \
	"$( rigHolds magic-tester Edit "$rigWs/RONLY/r.txt" ):$( rigHolds magic-tester Write "$rigWs/RONLY/w.txt" ):$( rigHolds magic-tester Execute "$rigWs/RONLY/run.sh" )" "NOT-HOLDS:NOT-HOLDS:NOT-HOLDS"
rigAssert "another member holds nothing there through it"  "$( rigHolds magic-developer Read "$rigWs/RONLY/r.txt" )" "NOT-HOLDS"
rigAssert "it is a read-grant root of its member"         "$( MMDAPP="$rigWs" AgentsToolsClientAccessReadGrantRoots magic-tester | LC_ALL=C grep -c -x -F "$rigWs/RONLY" )" 1
rigAssert "and no write root, named or not"                "$( MMDAPP="$rigWs" AgentsToolsClientAccessGrantRoots magic-tester | LC_ALL=C grep -c -x -F "$rigWs/RONLY" ):$( MMDAPP="$rigWs" AgentsToolsClientAccessGrantRoots | LC_ALL=C grep -c -x -F "$rigWs/RONLY" )" "0:0"
rigAssert "control: a path nothing grants is not readable" "$( rigHarnessRead magic-tester "$rigWs/ELSE/r.txt" )" refused
rigAssert "the harness reads there"                        "$( rigHarnessRead magic-tester "$rigWs/RONLY/r.txt" )" read
rigAssert "and refuses to write there, as its member"      "$( rigHarnessWrite magic-tester "$rigWs/RONLY/h.txt" )" "ERROR:"
rigAssert "or as a served call with no member"             "$( rigHarnessWrite "" "$rigWs/RONLY/h.txt" )" "ERROR:"
rigAssert "and nothing was written"                        "$( [ -e "$rigWs/RONLY/h.txt" ] && printf written || printf none )" none

echo "-- harness read roots are per member: the floor, its own Read and Edit rows, nobody else's --"
mkdir -p "$rigWs/source" "$rigWs/.local/temp/member/magic-tester"
printf 'rig-ronly-seed\n' > "$rigWs/source/f.txt"
printf 'rig-ronly-seed\n' > "$rigWs/.local/temp/member/magic-tester/f.txt"
printf 'rig-ronly-seed\n' > "$rigWs/DEV/r.txt"
rigAssert "the workspace source is in no member's read floor" "$( rigHarnessRead magic-tester "$rigWs/source/f.txt" )" refused
rigAssert "and its own temp scope"                         "$( rigHarnessRead magic-tester "$rigWs/.local/temp/member/magic-tester/f.txt" )" read
rigAssert "another member's allow-read row reaches nothing for it" "$( rigHarnessRead magic-developer "$rigWs/RONLY/r.txt" )" refused
rigAssert "an Edit row implies read for its own member"    "$( rigHarnessRead magic-developer "$rigWs/DEV/r.txt" )" read
rigAssert "and for no other member"                        "$( rigHarnessRead magic-tester "$rigWs/DEV/r.txt" )" refused
rigAssert "a served call with no member keeps every row"   "$( rigHarnessRead "" "$rigWs/RONLY/r.txt" ):$( rigHarnessRead "" "$rigWs/DEV/r.txt" )" "read:read"
rigReadRefusal="$( LC_ALL=C grep -l -x -F "target: $rigWs/DEV/r.txt" "$rigWs/.local/agents/sessions/rig-harness"/refusal-*.md 2>/dev/null | head -1 )"
rigAssert "a refused read is recorded in the session's store, as a write is" "$( rigField "$rigReadRefusal" tool ):$( rigField "$rigReadRefusal" owner )" "Read:magic-tester"

rigAssert "no request left this box"                       "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION HOLDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PERMISSION_HOLDS: OK (%d assertions, offline)\n' "$rigPassCount"
