#!/usr/bin/env bash
## Behavioural check on the team permission model (AgentsTools.PermissionHolds.include):
## the layers a member holds, no approving what you don't hold, routing up the chain,
## passing a permission on within its limits, a task's permission set, task expiry,
## per-member harness write roots, an allow-read row that reads but never writes, and the event-track
## posts of a pass, of a set applied and of a set denied. Offline: a Slack-shaped fake curl is first on PATH,
## a ps that lists the rig's own runs only is beside it, and everything runs in a workspace under this
## check's temp tree.
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
## THE RIG'S OWN PROCESS LIST. A spawn is found running by its spawn id in the host's process
## list (AgentsToolsRegistryRunningSpawns). A rig that read the real list would take any process
## of this host whose command line holds one of its ids -- another run of this check, a session
## whose brief quotes one -- for a live run of its own. So the ps first on PATH answers the
## whole-host listing from the rig's own list, one `<pid> <command line>` line a run, and hands
## every other call to the real ps.
RIG_PS_REAL="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
RIG_PS_LIST="$rigTmp/ps.list"
export RIG_PS_REAL RIG_PS_LIST
: > "$RIG_PS_LIST"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "$RIG_PS_LIST" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "$RIG_PS_LIST" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "$RIG_PS_REAL" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

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
## Each record names this host, so its run can be measured here.
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigSpawnRecord(){ ## spawn id, owner, parent session id
	printf -- '---\nsession-id: rig-cow\nspawn-id: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "${3:+parent-session-id: $3$'\n'}" "$rigHost" "$2" > "$rigWs/.local/agents/spawned/rig-cow/$1.md"
}
## A LIVE RUN of one spawn: a line of the rig's own process list that carries its spawn id, which
## is how the spawned-sessions render finds a spawn running. Ended by rigDead.
rigLive(){ ## spawn id
	printf '%s rig-run --session-id %s\n' "$(( 900000 + RANDOM ))" "$1" >> "$RIG_PS_LIST"
}
rigDead(){ ## spawn id
	LC_ALL=C awk -v gone="$1" '$NF != gone' "$RIG_PS_LIST" > "$RIG_PS_LIST.next" && mv -f "$RIG_PS_LIST.next" "$RIG_PS_LIST"
}
rigSpawnRecord rig-coord magic-coordinator ""
rigSpawnRecord rig-dev magic-developer rig-coord
rigSpawnRecord rig-tester magic-tester rig-coord
## The developer runs now, and the session rig-cow has a thread: a holder taking part is told there.
rigLive rig-dev
mkdir -p "$rigWs/.local/agents/sessions/rig-cow"
printf 'CRIG00001:1700000000.000900\n' > "$rigWs/.local/agents/sessions/rig-cow/session.thread"
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
rigSaid(){ ## fixed text... -> how many posts hold every one of them
	local saidFile saidText saidCount=0 saidAll
	for saidFile in "$rigTmp"/post.[0-9]* ; do
		[ -f "$saidFile" ] || continue
		saidAll=1
		for saidText in "$@" ; do LC_ALL=C grep -q -F -- "$saidText" "$saidFile" || { saidAll="" ; break ; } ; done
		[ -z "$saidAll" ] || saidCount=$(( saidCount + 1 ))
	done
	printf '%s' "$saidCount"
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

echo "-- allow for this session is that run's own: no other participant of the coworking session is let through --"
rigIdSession="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/s.txt" )"
rigAssert "a session grant for one participant's refused call"  "$( rigGrantOpen human-owner rig-tester "$rigIdSession" session )" "0 GRANT:"
## A second run of the same member in the same coworking session, for this block only.
rigSpawnRecord rig-tester-2 magic-tester rig-coord
rigAssert "admits that participant's own call"              "$( rigGrantRead magic-tester rig-tester Write "$rigWs/ELSE/s.txt" )" session
rigAssert "and not the same call of another participant"    "$( rigGrantRead magic-developer rig-dev Write "$rigWs/ELSE/s.txt" )" ""
rigAssert "nor of another run of the same member in that session" "$( rigGrantRead magic-tester rig-tester-2 Write "$rigWs/ELSE/s.txt" )" ""
rigAssert "it is kept in that run's own store, never in the coworking session's" \
	"$( cat "$rigWs/.local/agents/sessions/rig-tester/grants" 2>/dev/null | LC_ALL=C grep -c -F -- "$rigIdSession" ):$( cat "$rigWs/.local/agents/sessions/rig-cow/grants" 2>/dev/null | LC_ALL=C grep -c -F -- "$rigIdSession" )" "1:0"
rm -f "$rigWs/.local/agents/spawned/rig-cow/rig-tester-2.md"

echo "-- rule 1 on the escalation answer: routed to a holder participant --"
rigIdR="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/r.txt" )"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdR" )"
[ -n "$rigPend" ] || rigRefuse "no escalation record could be opened"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-session
rigAssert "the coordinator's allow is not applied"         "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPend rerouted" )" yes
rigAssert "it is re-addressed to the holder, who runs in this session" "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to )" magic-developer
rigAssert "the holder is told in the session's thread, by name, with why it is theirs and the request to name, its id at the end and never at the head of the line" \
	"$( rigSaid 'A permission request asked by magic-tester is now yours to answer, magic-developer. magic-coordinator does not hold Write on `' "naming request \`$rigPend\`." '"thread_ts":"1700000000.000900"' ):$( rigSaid "Permission request $rigPend" )" "1:0"
rigAssert "its record says who it waits on now"             "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" blocked-on )" "reply from magic-developer"
rigAssert "and the thread it was answered in is told the answer is not applied, and who it goes to" \
	"$( rigSaid 'Read: `allow-session` by magic-coordinator, and it is not applied: magic-coordinator does not hold Write' 'The question now goes to magic-developer, and stays open.' '"thread_ts":"1700000000.000001"' )" 1
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
rigForwardTs="$( rigField "$rigWs/.local/agents/pending/$rigPend.md" forward-ts )"
rigAssert "the request is posted to the human-owner with why it came up, and its three answer emoji are placed under it" \
	"$( LC_ALL=C grep -l -F 'The answer in this thread is the verdict for this request. magic-coordinator does not hold Write on `' "$rigTmp"/post.[0-9]* 2>/dev/null | LC_ALL=C awk 'END { print NR }' ):$( LC_ALL=C awk -v want="$rigForwardTs" '$1 == want { printf "%s ", $2 ; }' "$rigTmp/reactions" 2>/dev/null )" "1:x one repeat "
rigAssert "and it shows the human-owner no request id" \
	"$( LC_ALL=C grep -l -F 'The answer in this thread is the verdict' "$rigTmp"/post.[0-9]* 2>/dev/null | LC_ALL=C xargs grep -l -F -- "$rigPend" 2>/dev/null | LC_ALL=C awk 'END { print NR }' )" 0
rigAssert "its record says it waits on the human-owner"    "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" blocked-on )" "reply from human-owner"
## A holder that is not running in this session is never chosen: nobody there would see the request.
rigDead rig-dev
rigIdN="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/n.txt" )"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdN" )"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-session
rigAssert "a holder with no live run in the session is passed over: the request goes to the human-owner, posted" \
	"$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to ):$( [ -n "$( rigField "$rigWs/.local/agents/pending/$rigPend.md" forward-ts )" ] && printf posted || printf silent )" "human-owner:posted"
## Where it cannot be posted to who it goes up to, it is not re-addressed at all, and that is said.
rigIdQ="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/q2.txt" )"
rigPend="$( rigPermissionAsk magic-tester rig-tester "$rigIdQ" )"
: > "$rigTmp/post-refuse"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-escalation-answer magic-coordinator "$rigPend" allow-session
rm -f "$rigTmp/post-refuse"
rigAssert "a request that cannot be posted to the human-owner is not re-addressed, and the answer says so" \
	"$( rigField "$rigWs/.local/agents/pending/$rigPend.md" address-to ):$( rigField "$rigWs/.local/agents/pending/$rigPend.md" status ):$( rigHas "$rigTmp/op.err" 'could not be posted to the human-owner either, so it is NOT re-addressed' )" "magic-coordinator:reply-pending:yes"
rigLive rig-dev

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
	--entry "WebFetch:https://api.rig.example/*" --entry "cred:rig-api-token" --scope task --session-id rig-cow \
	--participant magic-developer --participant magic-tester
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

echo "-- what became of a permission is said in the session's tracking-thread: a pass, a set applied, a set denied --"
## Event-track is configured from here on, so nothing above posts to it. The posts since a
## mark that hold every text given, counted.
printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigTrackFrom=0
rigTrackMark(){
	rigTrackFrom="$( cat "$rigTmp/posts" 2>/dev/null || echo 0 )"
}
rigTrackPosts(){ ## fixed text...
	local trackNo=$(( rigTrackFrom + 1 )) trackText trackHit trackCount=0
	while [ -f "$rigTmp/post.$trackNo" ] ; do
		trackHit=1
		for trackText in "$@" ; do
			LC_ALL=C grep -q -F -- "$trackText" "$rigTmp/post.$trackNo" || { trackHit=0 ; break ; }
		done
		trackCount=$(( trackCount + trackHit ))
		trackNo=$(( trackNo + 1 ))
	done
	printf '%s' "$trackCount"
}
rigTrackMark
RIG_OP_AGENT=magic-developer RIG_OP_SESSION=rig-dev
rigOp --member-permission-pass magic-developer --to magic-tester --tool Write --target "$rigWs/DEV/track/**" --kind session
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigAssert "a pass is written"                              "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/op.out" )" session
rigAssert "and said in one grant post: the call, who passed it, to whom, how far" \
	"$( rigTrackPosts '✅ permission granted' 'tool: `Write`' "target: \`$rigWs/DEV/track/**\`" 'granted by: magic-developer · member: magic-tester · scope: session, passed on' ):$( rigTrackPosts '✅ permission granted' )" "1:1"
rigTrackThread="$( cat "$rigWs/.local/agents/sessions/rig-cow/event-track.thread" 2>/dev/null )"
rigAssert "it opens the tracking-thread of the session the grant is written in, recorded once" "${rigTrackThread#*:}:$( LC_ALL=C grep -c -F '"thread_ts"' "$rigTmp/post.$(( rigTrackFrom + 1 ))" )" "1700000001.00010$(( rigTrackFrom + 1 )):0"
rigTrackMark
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
rigOp --magic-permission-set-request magic-coordinator task-rig --entry "WebFetch:https://track.rig.example/*" --scope task --session-id rig-cow \
	--participant magic-coordinator --participant magic-developer --participant magic-tester
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigTrackSet="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
[ -n "$rigTrackSet" ] || rigRefuse "the rig asked for no permission set to apply"
## The participants the set is for, as the request itself said them.
rigTrackParts="$( LC_ALL=C sed -n 's/^PARTICIPANTS: //p' "$rigTmp/op.out" )"
rigTrackPartCount="$( printf '%s\n' $rigTrackParts | LC_ALL=C grep -c . )"
rigAssert "the set is for the members it names, the three of the rig" \
	"$( [ "$rigTrackPartCount" -ge 3 ] && printf enough || printf few ):$( printf '%s\n' $rigTrackParts | LC_ALL=C grep -c -x -e magic-coordinator -e magic-developer -e magic-tester )" "enough:3"
rigAssert "asking for a set posts no grant"                "$( rigTrackPosts '✅ permission granted' )" 0
RIG_OP_SESSION=rig-human rigOp --member-escalation-answer human-owner "$rigTrackSet" allow-set
rigAssert "a set applied"                                  "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigTrackSet answered" ):$( rigHas "$rigTmp/op.out" 'GRANT: set ' )" "yes:yes"
rigAssert "is said in one grant post for each participant, in that same thread" \
	"$( rigTrackPosts '✅ permission granted' "permission set $rigTrackSet, 1 permission(s)" "\"thread_ts\":\"${rigTrackThread#*:}\"" ):$( rigTrackPosts '✅ permission granted' )" "$rigTrackPartCount:$rigTrackPartCount"
for rigTrackPart in $rigTrackParts ; do
	rigAssert "one names $rigTrackPart, who granted it and how far" "$( rigTrackPosts "granted by: human-owner · member: $rigTrackPart · scope: set, task task-rig" )" 1
done
rigAssert "and no denial post"                             "$( rigTrackPosts '❌ permission denied' )" 0
rigTrackMark
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
rigOp --magic-permission-set-request magic-coordinator task-rig --entry "WebFetch:https://deny.rig.example/*" --scope session --session-id rig-cow
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigTrackDenied="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
[ -n "$rigTrackDenied" ] || rigRefuse "the rig asked for no permission set to deny"
RIG_OP_SESSION=rig-human rigOp --member-escalation-answer human-owner "$rigTrackDenied" deny
rigAssert "a set denied"                                   "$( rigHas "$rigTmp/op.out" "ESCALATION: $rigTrackDenied answered" ):$( rigField "$rigWs/.local/agents/pending/$rigTrackDenied.md" verdict )" "yes:deny"
rigAssert "is said in one denial post in that same thread: the set, who denied it, who asked" \
	"$( rigTrackPosts '❌ permission denied' "permission set $rigTrackDenied, 1 permission(s)" 'denied by: human-owner · member: magic-coordinator' "\"thread_ts\":\"${rigTrackThread#*:}\"" ):$( rigTrackPosts '❌ permission denied' )" "1:1"
rigAssert "with no grant post, and no grant"               "$( rigTrackPosts '✅ permission granted' ):$( rigGrantRead magic-tester rig-tester WebFetch https://deny.rig.example/x )" "0:"
## A target is shown to a person by its location root, <place>:<relative path>, where it lies
## in a registered place, and as given where it lies in none. The rig workspace is registered
## as a place only now, so the pass above showed its target as given.
printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
rigTrackMark
rigPlaceRefusal="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/place.txt" )"
[ -n "$rigPlaceRefusal" ] || rigRefuse "the rig logged no refusal in the registered place"
rigAssert "a refusal in a registered place shows its target by the place, and no absolute path" \
	"$( rigTrackPosts '🚫 refusal' 'target: `rig-ws:ELSE/place.txt`' ):$( rigTrackPosts "$rigWs/ELSE" )" "1:0"
rigAssert "its record keeps the exact target"              "$( rigField "$rigWs/.local/agents/sessions/rig-tester/$rigPlaceRefusal.md" target )" "$rigWs/ELSE/place.txt"
rigTrackMark
rigAssert "control: its grant is written from that record" "$( rigGrantOpen human-owner rig-tester "$rigPlaceRefusal" session )" "0 GRANT:"
rigAssert "the grant post shows the place too, and no absolute path" \
	"$( rigTrackPosts '✅ permission granted' 'target: `rig-ws:ELSE/place.txt`' ):$( rigTrackPosts "$rigWs/ELSE" )" "1:0"
rigAssert "and the grant admits the exact path"            "$( rigGrantRead magic-tester rig-tester Write "$rigWs/ELSE/place.txt" )" session
rigTrackMark
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionAnswerPost denial magic-tester "$rigWs/.local/agents/sessions/rig-tester" rig-tester refusal-rig Write "$rigWs/ELSE/other.txt" magic-coordinator | rigOp --intern-mcp-execute
rigAssert "a denial post shows the place too, and no absolute path" \
	"$( rigTrackPosts '❌ permission denied' 'target: `rig-ws:ELSE/other.txt`' ):$( rigTrackPosts "$rigWs/ELSE" )" "1:0"
rigTrackMark
rigRefusal magic-tester rig-tester Write /nowhere/rig-outside/x.txt > /dev/null
rigAssert "a target in no registered place is shown as given" "$( rigTrackPosts '🚫 refusal' 'target: `/nowhere/rig-outside/x.txt`' )" 1
rm -f "$rigWs/.local/agents/directories.registry"
rigAssert "the session still has the one tracking-thread"  "$( cat "$rigWs/.local/agents/sessions/rig-cow/event-track.thread" 2>/dev/null )" "$rigTrackThread"

echo "-- the permission set post: grouped by place, each place once by its location root, and what it is about --"
## A session rig-set of three participants, each spawn on its own host with its own
## description; a dispatch that tracks a task; the rig workspace registered as the place rig-ws.
printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
mkdir -p "$rigWs/.local/agents/spawned/rig-set"
rigSetRecord(){ ## spawn id, owner, host, description (may be empty), further header lines (may be empty)
	printf -- '---\nsession-id: rig-set\nspawn-id: %s\nowner: %s\nhost: %s\n%s%sstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "$2" "$3" "${4:+description: $4$'\n'}" "${5:-}" > "$rigWs/.local/agents/spawned/rig-set/$1.md"
}
rigSetRecord rig-set magic-coordinator rig-host-a 'rework the vars loader' $'session-thread: CRIG00001:1700000000.000500\n'
## The developer's spawn of that session runs on this host, live: what it holds counts as held.
rigSetRecord rig-set-dev magic-developer "$rigHost" 'change the loader code'
rigLive rig-set-dev
## A task set is for the members it names: these three, in the requests below that say so.
rigSetThree=( --participant magic-coordinator --participant magic-developer --participant magic-tester )
rigSetRecord rig-set-tester magic-tester rig-host-c 'check it against the samples'
printf -- '---\nstatus: task\nowner: magic-developer\n---\n\n# Fix the vars loader\n\nThe loader drops a variable whose value holds an equals sign. It must keep the whole value! Add a check for it. Then run the suite? A fifth sentence that must not show.\n' \
	> "$rigData/board/running/task-rig-set.md"
printf -- '---\nstatus: dispatch-started\nowner: magic-developer\nsession-id: rig-set\ntracks: task-rig-set\n---\n\n# Spawn-proxy dispatch: magic-developer\n\n## Brief\n\nthe brief of the dispatch.\n' \
	> "$rigData/board/running/dispatch-rig-set.md"
## The body as posted: the request's record keeps it, under its own heading.
rigSetBody(){ ## pending id
	LC_ALL=C awk 'inBody { print ; } $0 == "# Question asked" { inBody = 1 ; }' "$rigWs/.local/agents/pending/$1.md" 2>/dev/null | LC_ALL=C awk 'NF || seen { seen = 1 ; print ; }'
}
rigSetAsk(){ ## item, request options... -> the pending id
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
	rigOp --magic-permission-set-request magic-coordinator "$@"
	RIG_OP_AGENT="" RIG_OP_SESSION=""
	LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out"
}
rigSetHost="$( hostname -s 2>/dev/null || echo unknown )"
## A purpose for each of two places, tools given out of order, one place in no registry, one entry held.
rigSetId="$( rigSetAsk dispatch-rig-set --entry "Write:$rigWs/SETP/**" --entry "Read:$rigWs/SETP/**" --entry "Glob:$rigWs/SETP/**" --entry "Edit:$rigWs/SETP/**" --entry "Grep:$rigWs/SETP/**" \
	--purpose 'need to read some files' --entry "Write:$rigWs/SETQ/**" --entry "Read:$rigWs/SETQ/**" --purpose 'want to update vars there' \
	--entry 'Read:/nowhere/rig-set/**' --entry "Edit:$rigWs/DEV/held/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
[ -n "$rigSetId" ] || rigRefuse "the rig's permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigSetBody "$rigSetId" > "$rigTmp/set.body"
rigAssert "five tools on one place are one line, two places two lines each with its own tools in one fixed order, and a target in no place keeps its path" \
	"$( LC_ALL=C awk '$0 == "**➕ Asked for**" { on = 1 ; next ; } on && /^$/ { exit ; } on && /^- / { print ; }' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" \
	'- `rig-ws:SETP/**` — Read, Grep, Glob, Edit, Write|- `rig-ws:SETQ/**` — Read, Write|- `/nowhere/rig-set/**` — Read|'
rigAssert "each purpose is right under its place, first after the question, and a place with none has no such line" \
	"$( sed -n '3,10p' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" \
	'May the participants have these, for this task only?||**➕ Asked for**|- `rig-ws:SETP/**` — Read, Grep, Glob, Edit, Write|  - need to read some files|- `rig-ws:SETQ/**` — Read, Write|  - want to update vars there|- `/nowhere/rig-set/**` — Read|'
rigAssert "what is held is grouped the same way, with its holder" \
	"$( LC_ALL=C awk '$0 == "**✅ Already held, passed on by the holder**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" '- `rig-ws:DEV/held/**` — Edit (magic-developer)|'
rigAssert "no absolute path of the place is anywhere in the post, no separate list of places, and no line is written twice" \
	"$( LC_ALL=C grep -c -F "$rigWs" "$rigTmp/set.body" ):$( LC_ALL=C grep -c -e 'Places' -e ' is rig-ws:' "$rigTmp/set.body" ):$( LC_ALL=C grep . "$rigTmp/set.body" | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C grep -c . )" "0:0:0"
rigAssert "with a purpose given the task is its title with both names, and no longer text" \
	"$( LC_ALL=C awk '$0 == "**🗂 Task**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" 'Fix the vars loader|`task-rig-set` · `dispatch-rig-set`|'
rigAssert "the session: its short id, its thread, and what the spawn that started it said it is for" \
	"$( LC_ALL=C awk '$0 == "**🧵 Session**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" )" '`rig-set` · `CRIG00001:1700000000.000500` — rework the vars loader'
rigAssert "each participant with the host its spawn runs on and what it was brought in for" \
	"$( LC_ALL=C awk '$0 == "**👥 Participants**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )" \
	"- magic-coordinator · host rig-host-a — rework the vars loader|- magic-developer · host $rigHost — change the loader code|- magic-tester · host rig-host-c — check it against the samples|"
rigAssert "who asks and where, and how to answer, said once with whom an allow reaches" \
	"$( LC_ALL=C awk '$0 == "**🙋 Asked by**" { on = 1 ; next ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" \
	"magic-coordinator · $rigSetHost / ${rigWs##*/}||Click ❌ to deny, or 🔓 to allow the set. An allow gives these to every participant listed.|Or reply with the first word: allow-set, deny, or edit followed by the change.|"
rigAssert "the post that went out is that body, to the human-owner" \
	"$( LC_ALL=C grep -l -F 'rig-ws:SETP/**' "$rigTmp"/post.[0-9]* 2>/dev/null | LC_ALL=C awk 'END { print NR }' ):$( rigField "$rigWs/.local/agents/pending/$rigSetId.md" kind ):$( rigField "$rigWs/.local/agents/pending/$rigSetId.md" address-to )" "1:permission-set:human-owner"
rigAssert "the record keeps every entry exactly as asked, with its exact target, and each purpose with its place" \
	"$( LC_ALL=C grep -c -x -F "entry: Write:$rigWs/SETP/**" "$rigWs/.local/agents/pending/$rigSetId.set" ):$( LC_ALL=C grep -c '^entry: ' "$rigWs/.local/agents/pending/$rigSetId.set" ):$( LC_ALL=C grep -c -x -F "purpose: $rigWs/SETP/**"$'\t''need to read some files' "$rigWs/.local/agents/pending/$rigSetId.set" ):$( LC_ALL=C grep -c -x -F "purpose: $rigWs/SETQ/**"$'\t''want to update vars there' "$rigWs/.local/agents/pending/$rigSetId.set" ):$( LC_ALL=C grep -c '^purpose: ' "$rigWs/.local/agents/pending/$rigSetId.set" )" "1:8:1:1:2"
RIG_OP_SESSION=rig-human rigOp --member-escalation-answer human-owner "$rigSetId" allow-set
rigAssert "an allow-set still writes the grants: every extra, for every participant, by its exact path" \
	"$( rigHas "$rigTmp/op.out" 'GRANT: set 24 entries for ' ):$( rigGrantRead magic-tester rig-set-tester Write "$rigWs/SETP/a/b.txt" ):$( rigGrantRead magic-developer rig-set-dev Read "$rigWs/SETQ/c.txt" ):$( rigGrantRead magic-tester rig-set-tester Read /nowhere/rig-set/x ):$( rigGrantRead magic-tester rig-set-tester Edit "$rigWs/DEV/held/x" )" "yes:task:task:task:"
rigAssert "and the set grant record says what each place's access is for" \
	"$( cat "$rigWs/.local/agents/sessions/rig-set"/set-*.md 2>/dev/null | LC_ALL=C grep -c -x -F -- "- $rigWs/SETP/**: need to read some files" )" 3
## No purpose, and no description on the dispatch: the task's own text stands in, cut at a sentence end.
rigSetId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETR/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
rigSetBody "$rigSetId" > "$rigTmp/set.body"
rigAssert "a request with no purpose is asked as any other" "$( [ -n "$rigSetId" ] && printf asked || printf refused ):$( LC_ALL=C grep -c '^  - ' "$rigTmp/set.body" ):$( LC_ALL=C grep -c '^purpose: ' "$rigWs/.local/agents/pending/$rigSetId.set" 2>/dev/null )" "asked:0:0"
rigAssert "with no purpose the task shows its title, both names and its first paragraph, four sentences at most, cut at a sentence end" \
	"$( LC_ALL=C awk '$0 == "**🗂 Task**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C tr '\n' '|' )" \
	'Fix the vars loader|`task-rig-set` · `dispatch-rig-set`|The loader drops a variable whose value holds an equals sign. It must keep the whole value! Add a check for it. Then run the suite?|'
rigAssert "and it still says the session, the participants with their hosts, who asks and the scope" \
	"$( LC_ALL=C grep -c -e '^`rig-set` · ' -e ' · host rig-host-c' -e "^magic-coordinator · $rigSetHost / " -e 'for this task only' "$rigTmp/set.body" )" 4
## A description the spawner gave for the dispatch leads that longer text.
printf -- '---\nstatus: dispatch-started\nowner: magic-developer\nsession-id: rig-set\ntracks: task-rig-set\ndescription: bring the loader in line with the vars file\n---\n\n# Spawn-proxy dispatch: magic-developer\n\n## Brief\n\nthe brief of the dispatch.\n' \
	> "$rigData/board/running/dispatch-rig-set.md"
rigSetId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETS/**" --scope session --session-id rig-set )"
rigSetBody "$rigSetId" > "$rigTmp/set.body"
rigAssert "the spawner's own description of the dispatch is that text where one was stored, and a session scope is said in its own words" \
	"$( LC_ALL=C awk '$0 == "**🗂 Task**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" | LC_ALL=C tail -n 1 ):$( sed -n 3p "$rigTmp/set.body" )" \
	'bring the loader in line with the vars file:May the participants have these, for this session only?'
## An item with no title, a request with no session: what there is, and no empty heading.
printf -- '---\nstatus: task\nowner: magic-tester\n---\n\nno heading here.\n' > "$rigData/board/running/task-rig-bare.md"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=""
rigOp --magic-permission-set-request magic-coordinator task-rig-bare --entry "Read:/nowhere/rig-bare/**" --scope task --session-id ''
RIG_OP_AGENT=""
rigSetId="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
rigSetBody "$rigSetId" > "$rigTmp/set.body"
rigAssert "an item with no title and no session: its name, its participant and who asks, and no heading with nothing under it" \
	"$( LC_ALL=C grep -c -x -F '`task-rig-bare`' "$rigTmp/set.body" ):$( LC_ALL=C grep -c -e 'Session' -e ' · host ' "$rigTmp/set.body" ):$( LC_ALL=C grep -c -x -F -- '- magic-tester' "$rigTmp/set.body" ):$( LC_ALL=C awk '/^\*\*/ { head = 1 ; next ; } head && /^$/ { empty++ ; } { head = 0 ; } END { print empty + 0 }' "$rigTmp/set.body" )" "1:0:1:0"
## The session's thread is a link where the workspace's address is configured.
printf 'SLACK_WORKSPACE_DOMAIN=rig-team.slack.com\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigSetId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETT/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
rigSetBody "$rigSetId" > "$rigTmp/set.body"
rigAssert "the session's thread is a link where the workspace's address is configured" \
	"$( LC_ALL=C awk '$0 == "**🧵 Session**" { on = 1 ; next ; } on && /^$/ { exit ; } on { print ; }' "$rigTmp/set.body" )" '`rig-set` · [thread](https://rig-team.slack.com/archives/CRIG00001/p1700000000000500) — rework the vars loader'
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --purpose 'a purpose with no entry before it' --entry "Read:$rigWs/SETU/**" --scope task --session-id rig-set
RIG_OP_AGENT="" RIG_OP_SESSION=""
rigAssert "a purpose that follows no entry is refused, said plainly, and nothing is posted for it" "$( rigHas "$rigTmp/op.err" 'follows the --entry options of the place it is for' ):$( LC_ALL=C grep -c '^PERMISSION-SET: ' "$rigTmp/op.out" )" "yes:0"
rm -f "$rigWs/.local/agents/directories.registry"

echo "-- the permission set by click: the cross denies, the unlock allows the set, nothing else grants --"
## The prompt's own thread as Slack returns it: the prompt, with the reactions a scenario puts on it.
rigSetThread(){ ## pending id, reactions (a JSON list body, may be empty)
	local threadTs
	threadTs="$( rigField "$rigWs/.local/agents/pending/$1.md" question-ts )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT9","text":"the set"%s}],"has_more":false}\n' "$threadTs" "${2:+,\"reactions\":[$2]}" > "$rigTmp/replies.$threadTs.json"
}
rigSetClick(){ ## emoji name, users (a JSON list body)
	printf '{"name":"%s","count":1,"users":[%s]}' "$1" "$2"
}
rigSetRead(){ ## pending id -- the read, as the asker's wait makes it
	RIG_OP_AGENT="" RIG_OP_SESSION=""
	rigOp --intern-op-escalation-read magic-coordinator "$1"
}
rigSetReacted="$( LC_ALL=C awk 'END { print NR + 0 ; }' "$rigTmp/reactions" 2>/dev/null || printf 0 )"
rigSetIdC="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETC/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
[ -n "$rigSetIdC" ] || rigRefuse "the rig's permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigSetFileC="$rigWs/.local/agents/pending/$rigSetIdC.md"
rigAssert "the two click answers are placed under the prompt, the cross then the unlock" \
	"$( LC_ALL=C awk -v want="$( rigField "$rigSetFileC" question-ts )" -v before="${rigSetReacted:-0}" 'NR > before && $1 == want { printf "%s ", $2 ; }' "$rigTmp/reactions" 2>/dev/null )" "x unlock "
rigAssert "and the post names them, with the typed answers" \
	"$( rigSetBody "$rigSetIdC" | LC_ALL=C grep -c -x -F -e 'Click ❌ to deny, or 🔓 to allow the set. An allow gives these to every participant listed.' -e 'Or reply with the first word: allow-set, deny, or edit followed by the change.' )" 2
rigSetThread "$rigSetIdC" "$( rigSetClick x '"URIGBOT9"' ),$( rigSetClick unlock '"URIGBOT9"' ),$( rigSetClick +1 '"URIGOWNER"' ),$( rigSetClick ok '"URIGOWNER"' )"
rigSetRead "$rigSetIdC"
rigAssert "the emoji the tooling placed, a thumbs up and an ok grant nothing: the set stays open" \
	"$( rigHas "$rigTmp/op.out" "ESCALATION: $rigSetIdC open" ):$( rigField "$rigSetFileC" status ):$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETC/a.txt" )" "yes:reply-pending:"
rigSetThread "$rigSetIdC" "$( rigSetClick x '"URIGBOT9"' ),$( rigSetClick unlock '"URIGBOT9","URIGOWNER"' )"
rigSetRead "$rigSetIdC"
rigAssert "the owner's click on the unlock allows the set, and its grants are written" \
	"$( rigHas "$rigTmp/op.out" "ESCALATION: $rigSetIdC answered" ):$( rigHas "$rigTmp/op.out" 'VERDICT: allow-set' ):$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETC/a.txt" )" "yes:yes:task"
## An apply that stopped after the set was granted, before its record closed, is completed by
## the next read: the set is applied a second time there, and writes nothing twice.
rigSetCounts(){ ## -> "<grant lines>:<set records>:<Decisions lines naming the request>:<allows entries>"
	printf '%s:%s:%s:%s' "$( LC_ALL=C grep -c -F 'SETC' "$rigWs/.local/agents/sessions/rig-set/grants" 2>/dev/null )" \
		"$( LC_ALL=C grep -l -x -F "escalation: $rigSetIdC" "$rigWs/.local/agents/sessions/rig-set"/set-*.md 2>/dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" \
		"$( cat "$rigData"/board/*/dispatch-rig-set.md "$rigData"/board/*/task-rig-set.md 2>/dev/null | LC_ALL=C grep -c -F "($rigSetIdC" )" \
		"$( cat "$rigData"/board/*/dispatch-rig-set.md "$rigData"/board/*/task-rig-set.md 2>/dev/null | LC_ALL=C grep '^allows: ' | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c -F 'SETC' )"
}
rigSetBefore="$( rigSetCounts )"
rigAssert "control: the set was applied once, and its note is marked applied" "$( [ "${rigSetBefore%%:*}" -gt 0 ] && printf granted || printf none ):$( [ -f "${rigSetFileC%.md}.answered/verdict.applied" ] && printf applied || printf none )" "granted:applied"
mv "${rigSetFileC%.md}.answered/verdict.applied" "${rigSetFileC%.md}.answered/verdict"
LC_ALL=C awk '$0 == "status: reply-received" && ! reopened { print "status: reply-pending" ; reopened = 1 ; next ; } { print ; }' "$rigSetFileC" > "$rigSetFileC.new" && mv "$rigSetFileC.new" "$rigSetFileC"
rigSetPosts="$( rigCalls chat.postMessage )"
rigSetRead "$rigSetIdC"
rigAssert "a set applied again by the read that completes a stopped apply writes nothing twice, and posts nothing" \
	"$( rigHas "$rigTmp/op.out" "ESCALATION: $rigSetIdC answered" ):$( rigField "$rigSetFileC" status ):$( rigSetCounts ):$(( $( rigCalls chat.postMessage ) - rigSetPosts ))" "yes:reply-received:$rigSetBefore:0"
rigSetIdD="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETD/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
rigSetThread "$rigSetIdD" "$( rigSetClick unlock '"URIGOWNER"' ),$( rigSetClick x '"URIGOWNER"' )"
rigSetRead "$rigSetIdD"
rigAssert "the cross denies, beside an unlock too, and nothing is granted" \
	"$( rigHas "$rigTmp/op.out" 'VERDICT: deny' ):$( rigField "$rigWs/.local/agents/pending/$rigSetIdD.md" status ):$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETD/a.txt" )" "yes:reply-received:"

echo "-- a set answered: its participants are told once in the session thread, and the answer is confirmed once in its own thread --"
rigThree="magic-coordinator, magic-developer, magic-tester"
rigAssert "an allowed set: one line for all its participants, in the session's thread" \
	"$( rigSaid "Permission set \`${rigSetIdC:0:8}\` is allowed by human-owner: 1 permission(s), for this task only, are granted to $rigThree. A call refused before can be made again." '"thread_ts":"1700000000.000500"' )" 1
rigAssert "and one confirmation in the prompt's own thread: what was read, by whom, what is granted, to whom, how far" \
	"$( rigSaid "Read: \`allow-set\` by human-owner. Granted: 1 permission(s) to $rigThree, for this task only." "\"thread_ts\":\"$( rigField "$rigSetFileC" question-ts )\"" )" 1
rigAssert "a denied set: one line in the session's thread saying nothing is granted" \
	"$( rigSaid "Permission set \`${rigSetIdD:0:8}\` is denied by human-owner: nothing is granted to $rigThree." '"thread_ts":"1700000000.000500"' )" 1
rigAssert "and one confirmation in the prompt's own thread: the deny, by whom, and that nothing is granted" \
	"$( rigSaid "Read: \`deny\` by human-owner. Nothing is granted to $rigThree." "\"thread_ts\":\"$( rigField "$rigWs/.local/agents/pending/$rigSetIdD.md" question-ts )\"" )" 1
rigSetPosts="$( rigCalls chat.postMessage )"
rigSetRead "$rigSetIdD" ; rigSetRead "$rigSetIdC"
rigAssert "a later read of an answered set says neither again" "$(( $( rigCalls chat.postMessage ) - rigSetPosts ))" 0

echo "-- a read says open, returned and unreadable apart; an allow that cannot be applied is said in the thread, once --"
rigPermissionAskAt(){ ## owner, session, refusal id, thread ts -- a permission asked in a thread of its own
	printf '# Permission\n\nMay I?\n' | ( cd "$rigWs" && env -u MDAT_SPAWN_AGENT MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" \
		--intern-op-pending-reply-open "$1" --to CRIG00001 --session-id "$2" --kind permission --address-to magic-coordinator \
		--refusal-id "$3" --channel CRIG00001 --question-ts "$4" --thread-ts "$4" --addressees URIGOWNER --asking-accounts ' URIGSELF1 ' 2>/dev/null )
}
rigThreadOf(){ ## thread ts, further messages (a JSON list body, may be empty), reactions on the question (a JSON list body, may be empty)
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"the question"%s}%s],"has_more":false}\n' "$1" "${3:+,\"reactions\":[$3]}" "${2:+,$2}" > "$rigTmp/replies.$1.json"
}
rigIdO="$( rigRefusal magic-tester rig-tester Write "$rigWs/ELSE/o.txt" )"
rigPendO="$( rigPermissionAskAt magic-tester rig-tester "$rigIdO" 1700000000.000777 )"
[ -n "$rigPendO" ] || rigRefuse "no escalation record could be opened in a thread of its own"
rigReadRc=0 ; rigOp --intern-op-escalation-read magic-tester "$rigPendO" || rigReadRc=$?
rigAssert "a thread that cannot be read is an error: the conversation, the identity it was read with and Slack's error, never RETURNED and never open" \
	"$rigReadRc:$( rigHas "$rigTmp/op.err" "whether $rigPendO is answered is NOT known: the thread CRIG00001:1700000000.000777 could not be read as member magic-tester: rig_no_replies" ):$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPendO unreadable" ):$( LC_ALL=C grep -c -e '^VERDICT: ' -e "^ESCALATION: $rigPendO open" "$rigTmp/op.out" ):$( rigField "$rigWs/.local/agents/pending/$rigPendO.md" status )" "1:yes:yes:0:reply-pending"
rigThreadOf 1700000000.000777 "" "$( rigSetClick x '"URIGSELF1"' ),$( rigSetClick one '"URIGSELF1"' ),$( rigSetClick repeat '"URIGSELF1"' )"
rigReadRc=0 ; rigOp --intern-op-escalation-read magic-tester "$rigPendO" || rigReadRc=$?
rigAssert "a thread holding only the question and the asker's own three emoji is open, with who it waits on, and no verdict line" \
	"$rigReadRc:$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPendO open" ):$( rigHas "$rigTmp/op.out" 'WAITING-ON: magic-coordinator' ):$( LC_ALL=C grep -c '^VERDICT' "$rigTmp/op.out" )" "0:yes:yes:0"
rigThreadOf 1700000000.000777 '{"ts":"1700000000.000780","user":"URIGOWNER","text":"which file is that?","thread_ts":"1700000000.000777"}'
rigOp --intern-op-escalation-read magic-tester "$rigPendO"
rigAssert "accepted sibling: a reply that names no answer is RETURNED, still open" \
	"$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPendO open" ):$( rigHas "$rigTmp/op.out" 'VERDICT: RETURNED' ):$( LC_ALL=C grep -c '^WAITING-ON' "$rigTmp/op.out" )" "yes:yes:0"
## The owner allows it, and the grant cannot be written: said in the thread, once, and the request stays open.
rigThreadOf 1700000000.000777 '{"ts":"1700000000.000781","user":"URIGOWNER","text":"allow-once","thread_ts":"1700000000.000777"}'
chmod a-w "$rigWs/.local/agents/sessions/rig-tester" "$rigWs/.local/agents/sessions/rig-tester/grants"
rigOp --intern-op-escalation-read magic-tester "$rigPendO"
rigOp --intern-op-escalation-read magic-tester "$rigPendO"
## Read while the store still cannot be written: a check of the call reads the ask once more, and applies nothing.
rigNoGrant="$( rigGrantRead magic-tester rig-tester Write "$rigWs/ELSE/o.txt" )"
chmod u+w "$rigWs/.local/agents/sessions/rig-tester" "$rigWs/.local/agents/sessions/rig-tester/grants"
rigAssert "an allow whose grant cannot be written: the thread is told it was not applied and nothing is granted, once for three reads, and the request stays open" \
	"$( rigSaid 'Read: `allow-once` by human-owner, and it could not be applied: nothing is granted, and the question stays open. The grant could not be written.' '"thread_ts":"1700000000.000777"' ):$( rigField "$rigWs/.local/agents/pending/$rigPendO.md" status ):$rigNoGrant" "1:reply-pending:"
rigOp --intern-op-escalation-read magic-tester "$rigPendO"
rigAssert "accepted sibling: with the store writable the same answer is applied, and confirmed with what is granted, to whom and how far" \
	"$( rigHas "$rigTmp/op.out" "ESCALATION: $rigPendO answered" ):$( rigSaid "Read: \`allow-once\` by human-owner. Granted: Write on $rigWs/ELSE/o.txt to magic-tester, for this one call." '"thread_ts":"1700000000.000777"' )" "yes:1"
rigSetPosts="$( rigCalls chat.postMessage )"
rigOp --intern-op-escalation-read magic-tester "$rigPendO"
rigAssert "and a second read confirms nothing again"      "$(( $( rigCalls chat.postMessage ) - rigSetPosts ))" 0

echo "-- who a task set is for, a list of tools in one entry, and a holder that is not running --"
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Read:$rigWs/SETW/**" --scope task --session-id rig-set
rigAssert "a task set with nobody named is for the members of that task, not for the session's participants" "$( LC_ALL=C sed -n 's/^PARTICIPANTS: //p' "$rigTmp/op.out" )" "magic-developer"
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Read:$rigWs/SETX/**" --scope task --session-id rig-set --participant magic-tester
rigAssert "a task set that names its members is for those only" "$( LC_ALL=C sed -n 's/^PARTICIPANTS: //p' "$rigTmp/op.out" )" "magic-tester"
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Read:$rigWs/SETY/**" --scope session --session-id rig-set
rigAssert "accepted sibling: a session set is for everyone in the session" "$( LC_ALL=C sed -n 's/^PARTICIPANTS: //p' "$rigTmp/op.out" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "magic-coordinator magic-developer magic-tester "
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Write,Read,Glob:$rigWs/SETZ/**" --scope task --session-id rig-set --participant magic-tester
rigSetIdZ="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
rigAssert "one entry naming three tools for one target is three entries on the record, one a tool" \
	"$( LC_ALL=C grep '^entry: ' "$rigWs/.local/agents/pending/$rigSetIdZ.set" 2>/dev/null | LC_ALL=C tr '\n' '|' )" "entry: Write:$rigWs/SETZ/**|entry: Read:$rigWs/SETZ/**|entry: Glob:$rigWs/SETZ/**|"
rigSetPosts="$( rigCalls chat.postMessage )" ; rigSetRc=0
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Read,Everything:$rigWs/SETZ2/**" --scope task --session-id rig-set --participant magic-tester || rigSetRc=$?
rigAssert "a list naming a tool the operation does not know is a correction, never a refusal: nothing is asked, and no word means every tool" \
	"$rigSetRc:$( LC_ALL=C grep -c "^CORRECTION: .*nothing was asked. The entry 'Read,Everything:$rigWs/SETZ2/\*\*' lists a tool this operation does not know: 'Everything'" "$rigTmp/op.err" ):$( LC_ALL=C grep -c -i -e 'refused' -e 'denied' "$rigTmp/op.err" ):$(( $( rigCalls chat.postMessage ) - rigSetPosts )):$( LC_ALL=C grep -c '^PERMISSION-SET: ' "$rigTmp/op.out" )" "6:1:0:0:0"
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Edit:$rigWs/DEV/held2/**" --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "control: an entry a participant with a live run holds is held, and nothing is asked" \
	"$( rigHas "$rigTmp/op.out" "HELD: Edit:$rigWs/DEV/held2/** by magic-developer standing" ):$( rigHas "$rigTmp/op.out" 'PERMISSION-SET: held' )" "yes:yes"
rigDead rig-set-dev
rigSetPosts="$( rigCalls chat.postMessage )"
rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Edit:$rigWs/DEV/held3/**" --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "an entry only a member that is not running holds is asked for, never said held with no live holder" \
	"$( rigHas "$rigTmp/op.out" "EXTRA: Edit:$rigWs/DEV/held3/**" ):$( LC_ALL=C grep -c -e '^HELD: ' -e '^PERMISSION-SET: held' "$rigTmp/op.out" ):$( LC_ALL=C grep -c '^PERMISSION-SET: asked ' "$rigTmp/op.out" ):$(( $( rigCalls chat.postMessage ) - rigSetPosts ))" "yes:0:1:1"
RIG_OP_AGENT="" RIG_OP_SESSION=""

echo "-- a participant named on a permission set may wait on its answer, though another session asked --"
rigSetThread "$rigSetIdZ" ""
RIG_OP_AGENT=magic-tester RIG_OP_SESSION=rig-set-tester rigOp --intern-op-wait-for-input magic-tester --wait-session-id rig-set-tester --wait-source "ask:$rigSetIdZ" --wait-timeout 0
rigAssert "a participant of the set waits on it: read, with the bot that posted it, and nothing there yet" \
	"$( LC_ALL=C grep -c 'may not wait on it' "$rigTmp/op.err" ):$( LC_ALL=C grep -c -x 'WAIT-RESULT: TIMEOUT' "$rigTmp/op.out" ):$( LC_ALL=C grep -c '^WAIT-NEVER-READ' "$rigTmp/op.out" )" "0:1:0"
RIG_OP_AGENT=magic-developer RIG_OP_SESSION=rig-set-dev rigOp --intern-op-wait-for-input magic-developer --wait-session-id rig-set-dev --wait-source "ask:$rigSetIdZ" --wait-timeout 0
rigAssert "accepted sibling: a member the set does not name may not" "$( LC_ALL=C grep -c "is a question asked by session rig-set, not rig-set-dev, so this session may not wait on it" "$rigTmp/op.err" )" 1
RIG_OP_AGENT="" RIG_OP_SESSION=""

echo "-- a call about to be refused first takes an answer that is already there on an open ask --"
rigReadRc=0 ; rigOp --intern-op-permission-grant-read magic-tester --session-id rig-set-tester --tool Read --target "$rigWs/SETZ/a.txt" || rigReadRc=$?
rigAssert "an open set that would allow the call, not answered yet: no grant, and the ask is named with who it waits on" \
	"$rigReadRc:$( LC_ALL=C grep -c '^GRANT: ' "$rigTmp/op.out" ):$( LC_ALL=C grep -c -x -F "OPEN-ASK: $rigSetIdZ permission-set human-owner" "$rigTmp/op.out" )" "1:0:1"
rigReadRc=0 ; rigOp --intern-op-permission-grant-read magic-tester --session-id rig-set-tester --tool Read --target "$rigWs/ELSE/never-asked.txt" || rigReadRc=$?
rigAssert "accepted sibling: a call no open ask covers names none" "$rigReadRc:$( LC_ALL=C grep -c '^OPEN-ASK' "$rigTmp/op.out" )" "1:0"
## An open set that asks only Edit of a folder would allow a read there too, as its grant will
## (AgentsToolsGrantsToolCovers), so it is named for one; never the other way.
RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-coord rigOp --magic-permission-set-request magic-coordinator dispatch-rig-set --entry "Edit:$rigWs/SETE/**" --entry "Read:$rigWs/SETR/**" --scope task --session-id rig-set --participant magic-tester
rigSetIdE="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
[ -n "$rigSetIdE" ] || rigRefuse "the rig's permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigSetThread "$rigSetIdE" ""
rigSetCovers=""
for rigSetTool in Read Grep Glob ; do
	rigReadRc=0 ; rigOp --intern-op-permission-grant-read magic-tester --session-id rig-set-tester --tool "$rigSetTool" --target "$rigWs/SETE/a.txt" || rigReadRc=$?
	rigSetCovers="$rigSetCovers$rigSetTool=$rigReadRc:$( LC_ALL=C grep -c '^GRANT: ' "$rigTmp/op.out" ):$( LC_ALL=C grep -c -x -F "OPEN-ASK: $rigSetIdE permission-set human-owner" "$rigTmp/op.out" ) "
done
rigAssert "an open set that asks only Edit of a folder is named for a Read, a Grep and a Glob there: it would allow them" "$rigSetCovers" "Read=1:0:1 Grep=1:0:1 Glob=1:0:1 "
rigReadRc=0 ; rigOp --intern-op-permission-grant-read magic-tester --session-id rig-set-tester --tool Write --target "$rigWs/SETR/a.txt" || rigReadRc=$?
rigAssert "never the other way: its entry that asks only Read of a folder names no ask for a Write there" "$rigReadRc:$( LC_ALL=C grep -c '^OPEN-ASK' "$rigTmp/op.out" )" "1:0"
rigReadRc=0 ; rigOp --intern-op-permission-grant-read magic-tester --session-id rig-set-tester --tool Edit --target "$rigWs/SETE/a.txt" || rigReadRc=$?
rigAssert "accepted sibling: the Edit it asks is named for an Edit there, as before" "$rigReadRc:$( LC_ALL=C grep -c -x -F "OPEN-ASK: $rigSetIdE permission-set human-owner" "$rigTmp/op.out" )" "1:1"
rigSetThread "$rigSetIdZ" "$( rigSetClick unlock '"URIGOWNER"' )"
rigAssert "the owner's click is there and nobody has read it: the check of the call applies it, and the call goes through" \
	"$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETZ/a.txt" ):$( rigField "$rigWs/.local/agents/pending/$rigSetIdZ.md" status ):$( rigField "$rigWs/.local/agents/pending/$rigSetIdZ.md" verdict )" "task:reply-received:allow-set"
rigAssert "and a member the set does not name is let through by none of it" "$( rigGrantRead magic-developer rig-set-dev Read "$rigWs/SETZ/a.txt" )" ""

echo "-- who a permission question goes to, settled when it is asked --"
rigRoute(){ ## asking member, session, refusal id, who was named -> who it goes to; the whole answer stays in op.out
	RIG_OP_AGENT="" RIG_OP_SESSION="" rigOp --intern-op-permission-route "$1" --session-id "$2" --refusal-id "$3" --address-to "$4"
	LC_ALL=C sed -n 's/^ROUTE: //p' "$rigTmp/op.out"
}
## The two refused calls first, each recorded (and tracked) before anything is counted.
printf 'magic-coordinator:ws:workspace:Edit(/%s/COORD/**)\n' "$rigWs" >> "$rigWs/.local/agents/permissions.registry"
mkdir -p "$rigWs/COORD"
rigIdRt="$( rigRefusal magic-tester rig-tester Write "$rigWs/DEV/route.txt" )"
rigIdRc="$( rigRefusal magic-tester rig-tester Write "$rigWs/COORD/c.txt" )"
rigRoutePosts="$( rigCalls chat.postMessage )"
rigAssert "the coordinator named, who does not hold it: it goes to the holder running in this session, and why is said" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-coordinator ):$( rigHas "$rigTmp/op.out" "ROUTE-REASON: magic-coordinator does not hold Write $rigWs/DEV/route.txt, and magic-developer holds it and runs in this session" )" "magic-developer:yes"
rigAssert "accepted sibling: the holder named, running: it stays with who was named, no reason given" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-developer ):$( LC_ALL=C grep -c '^ROUTE-REASON' "$rigTmp/op.out" )" "magic-developer:0"
rigDead rig-dev
rigAssert "the holder named, with no live run in this session: it goes to the human-owner, and why is said" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-developer ):$( rigHas "$rigTmp/op.out" 'ROUTE-REASON: magic-developer has no live run in this session, and nobody running in this session holds it' )" "human-owner:yes"
rigAssert "the coordinator named, the only holder not running: the human-owner, never the member who is not there" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-coordinator )" "human-owner"
## The holder's run is gone, and another participant's command line still holds its spawn id:
## inside the path of a folder, and quoted in its brief after the very words a launcher uses.
## A run is its own --session-id or --resume word alone (AgentsToolsRegistryRunningSpawns), so
## that line is the other participant's run and none of the holder's.
printf '900777 claude --add-dir %s/.local/agents/spawned/rig-dev/input --session-id rig-tester --agent magic-tester Readable %s/.local/agents/spawned/rig-dev/input, as said by --session-id rig-dev\n' "$rigWs" "$rigWs" >> "$RIG_PS_LIST"
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionSessionRunning rig-tester | rigOp --intern-mcp-execute
rigAssert "a spawn id standing inside a path, or quoted in a brief, of another participant's command line is no run of its spawn: that participant runs, the holder does not" \
	"$( LC_ALL=C sort "$rigTmp/op.out" | LC_ALL=C tr '\n' '|' )" "magic-tester|"
rigAssert "so the holder whose run is gone is not chosen: the question goes on to the human-owner" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-coordinator ):$( rigHas "$rigTmp/op.out" "ROUTE-REASON: magic-coordinator does not hold Write $rigWs/DEV/route.txt, and nobody running in this session holds it" )" "human-owner:yes"
rigDead rig-dev
## The same member running in another coworking session only: a run there is not told in this
## session's thread and answers nothing here, so it is no holder running in this session.
mkdir -p "$rigWs/.local/agents/spawned/rig-other"
printf -- '---\nsession-id: rig-other\nspawn-id: rig-other-dev\nhost: %s\nowner: magic-developer\nstatus: spawn-started\n---\n\n# Spawn session\n' \
	"$rigHost" > "$rigWs/.local/agents/spawned/rig-other/rig-other-dev.md"
rigLive rig-other-dev
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionSessionRunning rig-other-dev | rigOp --intern-mcp-execute
rigAssert "control: the holder's run in another coworking session is live, and is counted there" "$( LC_ALL=C tr '\n' '|' < "$rigTmp/op.out" )" "magic-developer|"
rigHelperScript AgentsTools.InternOpPermission.include AgentsToolsPermissionSessionRunning rig-tester | rigOp --intern-mcp-execute
rigAssert "a run in another coworking session is no run in this one" "$( LC_ALL=C grep -c -x -F 'magic-developer' "$rigTmp/op.out" )" 0
rigAssert "the holder running in another coworking session only is not chosen: the question goes on to the human-owner, and why is said" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-coordinator ):$( rigHas "$rigTmp/op.out" "ROUTE-REASON: magic-coordinator does not hold Write $rigWs/DEV/route.txt, and nobody running in this session holds it" )" "human-owner:yes"
rigAssert "nor when it is the one named: it has no live run in this session" \
	"$( rigRoute magic-tester rig-tester "$rigIdRt" magic-developer ):$( rigHas "$rigTmp/op.out" 'ROUTE-REASON: magic-developer has no live run in this session, and nobody running in this session holds it' )" "human-owner:yes"
rigDead rig-other-dev
rigLive rig-dev
rigAssert "the human-owner named stays the human-owner"     "$( rigRoute magic-tester rig-tester "$rigIdRt" human-owner ):$( LC_ALL=C grep -c '^ROUTE-REASON' "$rigTmp/op.out" )" "human-owner:0"
rigAssert "the coordinator named, who holds it: it stays, though its own session is no spawn of this one" \
	"$( rigRoute magic-tester rig-tester "$rigIdRc" magic-coordinator ):$( LC_ALL=C grep -c '^ROUTE-REASON' "$rigTmp/op.out" )" "magic-coordinator:0"
rigAssert "deciding who it goes to posts nothing"           "$(( $( rigCalls chat.postMessage ) - rigRoutePosts ))" 0

rigAssert "no request left this box"                       "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION HOLDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PERMISSION_HOLDS: OK (%d assertions, offline)\n' "$rigPassCount"
