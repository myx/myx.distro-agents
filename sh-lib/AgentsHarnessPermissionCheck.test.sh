#!/usr/bin/env bash
## Behavioural check on permission refusals and grants in the harness write gate, run
## through --intern-tool, the path the myx.distro MCP stub uses. A refusal is a
## recorded fact with an id, posted to the session's event-track thread, and never a
## verdict. Offline: a Slack-shaped fake curl is first on PATH, and every scenario
## runs in its own workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to record under"

rigTmp="$( mktemp -d -t AgentsHarnessPermissionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/bin"
cp "$rigHere/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigHere/check-fixtures/harness-ask-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

rigPassCount=0
rigFailCount=0
rigScenarioCount=0
rigScenarioPass=0
rigScenarioFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigScenarioPass=$(( rigScenarioPass + 1 ))
	else
		rigScenarioFail=$(( rigScenarioFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

rigVerdict(){ ## scenario title
	local verdictMark=PASS
	[ "$rigScenarioFail" = 0 ] || verdictMark=FAIL
	printf '  %s  %s -- %d of %d assertions\n' "$verdictMark" "$1" "$rigScenarioPass" "$(( rigScenarioPass + rigScenarioFail ))"
	rigPassCount=$(( rigPassCount + rigScenarioPass ))
	rigFailCount=$(( rigFailCount + rigScenarioFail ))
	rigScenarioCount=$(( rigScenarioCount + 1 ))
	rigScenarioPass=0
	rigScenarioFail=0
}

rigHolds(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in
		*"$2"*) printf 'yes' ;;
		*)      printf 'no' ;;
	esac
}

rigFirstLine(){ ## file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk 'NR == 1 { firstLine = $0 ; } END { if ( NR == 0 ) { firstLine = "empty-output" ; } print firstLine ; }' "$1"
}

rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" 2>/dev/null || printf 'no-such-log'
}

## The refusal id the tool result carries, or none.
rigRefusalId(){
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigScenarioDir/out" | head -1
}

## One field of one refusal record, or a value saying there is no record.
rigRecordField(){ ## refusal id, field
	local recordFile="$rigScenarioDir/ws/.local/agents/sessions/rig-session/$1.md"
	[ -n "$1" ] && [ -f "$recordFile" ] || { printf 'no-record' ; return 0 ; }
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$recordFile"
}

rigRecordCount(){
	local recordCount=0 recordFile
	for recordFile in "$rigScenarioDir/ws/.local/agents/sessions"/*/refusal-*.md ; do
		[ -f "$recordFile" ] || continue
		recordCount=$(( recordCount + 1 ))
	done
	printf '%s' "$recordCount"
}

rigScenarioDir=""
RIG_DATA_ROOT=""
rigStart(){ ## scenario directory name, event-track configured (yes|no)
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/IN" "$rigScenarioDir/ws/OUT"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	[ "$2" != "yes" ] || printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}

## One served tool call with its session and launch values stated outright.
rigTool(){ ## session id (may be empty), tool, argument object
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID \
		${1:+MDAT_SPAWN_SESSION_ID="$1"} ${RIG_DATA_ROOT:+MDAT_DATA_ROOT="$RIG_DATA_ROOT"} RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT="$rigMember" \
		bash "$rigHarness" --intern-tool "$2" --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" ) \
		> "$rigScenarioDir/out" 2> "$rigScenarioDir/err"
}

## ---------------------------------------------------------------------------
## 1. A refused Write with no event-track configured: the original ERROR stands,
##    a refusal is recorded locally with its tool and resolved target, and the
##    result names its id. Nothing is posted.
## ---------------------------------------------------------------------------
rigStart local-only no
rigTool rig-session Write "{\"path\":\"$rigScenarioDir/ws/OUT/x.txt\",\"content\":\"x\"}"
rigId="$( rigRefusalId )"
rigAssert "the original ERROR line opens the result"      "$( rigFirstLine "$rigScenarioDir/out" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigScenarioDir/ws/OUT/x.txt"
rigAssert "a refusal id is named"                          "$( [ -n "$rigId" ] && printf yes || printf no )" yes
rigAssert "the record is in the session's own store"       "$( rigRecordField "$rigId" status )" refused
rigAssert "it carries the tool"                            "$( rigRecordField "$rigId" tool )" Write
rigAssert "it carries the resolved target"                 "$( rigRecordField "$rigId" target )" "$rigScenarioDir/ws/OUT/x.txt"
rigAssert "it carries the session"                         "$( rigRecordField "$rigId" session-id )" rig-session
rigAssert "the result says it is not a verdict"            "$( rigHolds "$rigScenarioDir/out" 'This is a refusal, not a verdict' )" yes
rigAssert "the result names how to ask"                    "$( rigHolds "$rigScenarioDir/out" "kind=permission, refusal_id=$rigId" )" yes
rigAssert "nothing was written outside"                    "$( [ -e "$rigScenarioDir/ws/OUT/x.txt" ] && printf yes || printf no )" no
rigAssert "nothing was posted"                             "$( rigCalls chat.postMessage )" 0
rigVerdict "a refusal with no event-track -- recorded locally, id returned, nothing posted"

## ---------------------------------------------------------------------------
## 2. With event-track configured: the first refusal opens the session's thread
##    and names its id, the second threads into it. Edit is refused the same way.
## ---------------------------------------------------------------------------
rigStart event-track yes
rigTool rig-session Write "{\"path\":\"$rigScenarioDir/ws/OUT/a.txt\",\"content\":\"x\"}"
rigIdA="$( rigRefusalId )"
printf 'orig' > "$rigScenarioDir/ws/OUT/b.txt"
rigTool rig-session Edit "{\"path\":\"$rigScenarioDir/ws/OUT/b.txt\",\"old_text\":\"orig\",\"new_text\":\"x\"}"
rigIdB="$( rigRefusalId )"
rigAssert "two posts were made"                            "$( rigCalls chat.postMessage )" 2
rigAssert "the first post names the first id"              "$( rigHolds "$rigScenarioDir/post.1" "$rigIdA" )" yes
rigAssert "the first post opens a thread"                  "$( rigHolds "$rigScenarioDir/post.1" 'thread_ts' )" no
rigAssert "the second post names the second id"            "$( rigHolds "$rigScenarioDir/post.2" "$rigIdB" )" yes
rigAssert "the second post is in the first one's thread"   "$( rigHolds "$rigScenarioDir/post.2" '"thread_ts":"1700000001.000101"' )" yes
rigAssert "the ids differ"                                 "$( [ "$rigIdA" != "$rigIdB" ] && printf yes || printf no )" yes
rigAssert "the Edit refusal records its tool"              "$( rigRecordField "$rigIdB" tool )" Edit
rigAssert "and the outside file is unchanged"              "$( cat "$rigScenarioDir/ws/OUT/b.txt" )" orig
rigAssert "two records"                                    "$( rigRecordCount )" 2
rigVerdict "event-track -- the first refusal opens the session thread, the next one threads into it"

## ---------------------------------------------------------------------------
## 3. No session id at all: still a refusal, stated as unrecorded, with no id.
## ---------------------------------------------------------------------------
rigStart no-session no
rigTool "" Write "{\"path\":\"$rigScenarioDir/ws/OUT/x.txt\",\"content\":\"x\"}"
rigAssert "the original ERROR line opens the result"      "$( rigFirstLine "$rigScenarioDir/out" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigScenarioDir/ws/OUT/x.txt"
rigAssert "it says no id exists"                           "$( rigHolds "$rigScenarioDir/out" 'REFUSAL-ID: none' )" yes
rigAssert "no record was written"                          "$( rigRecordCount )" 0
rigVerdict "no session id -- refused, stated as unrecorded, no id issued"

## ---------------------------------------------------------------------------
## 4. The record cannot be written: still a refusal, and no id is issued for a
##    record that does not exist.
## ---------------------------------------------------------------------------
rigStart store-unwritable no
mkdir -p "$rigScenarioDir/ws/.local/agents/sessions"
chmod 500 "$rigScenarioDir/ws/.local/agents/sessions"
rigTool rig-session Write "{\"path\":\"$rigScenarioDir/ws/OUT/x.txt\",\"content\":\"x\"}"
chmod 700 "$rigScenarioDir/ws/.local/agents/sessions"
rigAssert "the original ERROR line opens the result"      "$( rigFirstLine "$rigScenarioDir/out" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigScenarioDir/ws/OUT/x.txt"
rigAssert "it says recording failed and no id exists"      "$( rigHolds "$rigScenarioDir/out" 'REFUSAL-ID: none -- recording the refusal failed' )" yes
rigAssert "no record was written"                          "$( rigRecordCount )" 0
rigVerdict "an unwritable store -- refused, and no id is issued"

## ---------------------------------------------------------------------------
## 5. A path always refused (relative) is recorded as given; an allowed write is
##    not a refusal and records nothing (the control).
## ---------------------------------------------------------------------------
rigStart relative-and-control no
rigTool rig-session Write '{"path":"OUT/x.txt","content":"x"}'
rigIdR="$( rigRefusalId )"
rigAssert "a relative path is refused and recorded as given" "$( rigRecordField "$rigIdR" target )" "OUT/x.txt"
rigTool rig-session Write "{\"path\":\"$rigScenarioDir/ws/IN/ok.txt\",\"content\":\"x\"}"
rigAssert "an allowed write succeeds"                      "$( rigFirstLine "$rigScenarioDir/out" )" "OK: wrote $rigScenarioDir/ws/IN/ok.txt"
rigAssert "and names no refusal"                           "$( rigHolds "$rigScenarioDir/out" 'REFUSAL-ID' )" no
rigAssert "one record only, the relative one"              "$( rigRecordCount )" 1
rigVerdict "a relative path is recorded as given, and an allowed write records nothing"

## One grant through the tooling op, as the verdict path will call it.
rigGrant(){ ## granting member, session id, refusal id, kind
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT MMDAPP="$rigScenarioDir/ws" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-open "$1" \
		--session-id "$2" --refusal-id "$3" --kind "$4" ) > "$rigScenarioDir/grant.out" 2> "$rigScenarioDir/grant.err"
	LC_ALL=C sed -n 's/^\(GRANT: .*\)$/\1/p' "$rigScenarioDir/grant.out" | head -1
}
rigWriteCall(){ ## session id, path
	rigTool "$1" Write "{\"path\":\"$2\",\"content\":\"x\"}"
	rigFirstLine "$rigScenarioDir/out"
}
rigOkLine(){ ## path
	printf 'OK: wrote %s' "$1"
}

## ---------------------------------------------------------------------------
## 6. Deny writes nothing: the retry is refused again, under a new refusal id.
## ---------------------------------------------------------------------------
rigStart deny no
rigTarget="$rigScenarioDir/ws/OUT/d.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdFirst="$( rigRefusalId )"
rigAssert "the retry is refused again"                     "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "under a new refusal id"                         "$( rigIdNew="$( rigRefusalId )" ; [ -n "$rigIdNew" ] && [ "$rigIdNew" != "$rigIdFirst" ] && printf yes || printf no )" yes
rigAssert "and no grants file exists"                      "$( [ -e "$rigScenarioDir/ws/.local/agents/sessions/rig-session/grants" ] && printf yes || printf no )" no
rigVerdict "deny -- nothing is written, and a retry is a new refusal"

## ---------------------------------------------------------------------------
## 7. Allow once: the exact retry is admitted once, the next one is refused anew.
## ---------------------------------------------------------------------------
rigStart allow-once no
rigTarget="$rigScenarioDir/ws/OUT/o.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdOnce="$( rigRefusalId )"
rigAssert "the grant is opened from the record"            "$( rigGrant magic-coordinator rig-session "$rigIdOnce" once )" "GRANT: once $rigIdOnce"
rigAssert "another session cannot use it"                  "$( rigWriteCall rig-other "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "Edit on the same target is a different call"    "$( printf 'orig' > "$rigTarget.e" ; rigTool rig-session Edit "{\"path\":\"$rigTarget\",\"old_text\":\"orig\",\"new_text\":\"x\"}" ; rigFirstLine "$rigScenarioDir/out" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "the exact retry is admitted"                    "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "and the file was written"                       "$( cat "$rigTarget" 2>/dev/null )" x
rigAssert "the next identical call is refused"             "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "under a new refusal id"                         "$( rigIdNext="$( rigRefusalId )" ; [ -n "$rigIdNext" ] && [ "$rigIdNext" != "$rigIdOnce" ] && printf yes || printf no )" yes
rigVerdict "allow once -- admitted exactly once, only in its session, only for its tool"

## ---------------------------------------------------------------------------
## 8. An Allow once that cannot be used up is not used at all.
## ---------------------------------------------------------------------------
rigStart once-unconsumable no
rigTarget="$rigScenarioDir/ws/OUT/u.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigGrant magic-coordinator rig-session "$( rigRefusalId )" once > /dev/null
mkdir -p "$rigScenarioDir/ws/.local/agents/sessions/rig-session/consumed"
chmod 500 "$rigScenarioDir/ws/.local/agents/sessions/rig-session/consumed"
rigAssert "the retry is refused when the grant cannot be consumed" "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
chmod 700 "$rigScenarioDir/ws/.local/agents/sessions/rig-session/consumed"
rigAssert "and nothing was written"                        "$( [ -e "$rigTarget" ] && printf yes || printf no )" no
rigAssert "control: once consumable, the same retry passes" "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigVerdict "allow once fails closed when it cannot be used up"

## ---------------------------------------------------------------------------
## 9. Allow in this session: every exact retry in the session, and nothing wider.
## ---------------------------------------------------------------------------
rigStart allow-session no
rigTarget="$rigScenarioDir/ws/OUT/foo"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigGrant magic-coordinator rig-session "$( rigRefusalId )" session > /dev/null
rigAssert "the first retry is admitted"                    "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "the second retry is admitted too"               "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "a similar path is not admitted"                 "$( rigWriteCall rig-session "${rigTarget}bar" )" "ERROR: path not in the allowed write-root set -- it may still be readable: ${rigTarget}bar"
rigAssert "a path under it is not admitted"                "$( rigWriteCall rig-session "$rigTarget.d/x" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget.d/x"
rigAssert "a dotdot spelling of it is not admitted"        "$( rigWriteCall rig-session "$rigScenarioDir/ws/OUT/../OUT/foo" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigScenarioDir/ws/OUT/../OUT/foo"
rigAssert "another session is not admitted"                "$( rigWriteCall rig-other "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "no session id is not admitted"                  "$( rigWriteCall "" "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
mkdir -p "$rigScenarioDir/ws/ELSEWHERE"
printf 'orig' > "$rigScenarioDir/ws/ELSEWHERE/z"
rm -f "$rigTarget" ; ln -s "$rigScenarioDir/ws/ELSEWHERE/z" "$rigTarget"
rigAssert "the granted path swapped for a link out is not admitted" "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigAssert "and the link's target is unchanged"             "$( cat "$rigScenarioDir/ws/ELSEWHERE/z" )" orig
rigVerdict "allow in this session -- exact target, this session only, never wider"

## ---------------------------------------------------------------------------
## 10. Nobody grants to itself, and a grant is only ever for a recorded refusal.
## ---------------------------------------------------------------------------
rigStart self-grant no
rigTarget="$rigScenarioDir/ws/OUT/s.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdSelf="$( rigRefusalId )"
rigAssert "the asking member cannot grant itself"          "$( rigGrant "$rigMember" rig-session "$rigIdSelf" session )" ""
rigAssert "an unrecorded refusal id grants nothing"        "$( rigGrant magic-coordinator rig-session refusal-00000000-0000-0000-0000-000000000000 session )" ""
printf 'session:Write:%s:%s:20260101T0000Z:%s\n' "$rigTarget" "$rigMember" "$rigIdSelf" >> "$rigScenarioDir/ws/.local/agents/sessions/rig-session/grants"
printf 'session:Write:%s::20260101T0000Z:%s\n' "$rigTarget" "$rigIdSelf" >> "$rigScenarioDir/ws/.local/agents/sessions/rig-session/grants"
rigAssert "a hand-written self-grant and an unsigned one admit nothing" "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigVerdict "no self-grant, and no grant without a recorded refusal"

## ---------------------------------------------------------------------------
## 11. A grant never reaches into a team store an unattended session is kept out of.
## ---------------------------------------------------------------------------
rigStart grant-vs-store no
mkdir -p "$rigScenarioDir/ws/DATA/board"
RIG_DATA_ROOT="$rigScenarioDir/ws/DATA"
rigTarget="$rigScenarioDir/ws/DATA/board/x.md"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigGrant magic-coordinator rig-session "$( rigRefusalId )" session > /dev/null
rigAssert "the granted retry is still refused by the store rule" "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path is in a team store that an unattended session never writes with Write or Edit -- use the team tooling operation for it: $rigTarget"
rigAssert "and nothing was written"                        "$( [ -e "$rigTarget" ] && printf yes || printf no )" no
RIG_DATA_ROOT=""
rigVerdict "a grant does not override the team-store rule"

rigAskPid=""
rigAskFinish(){ ## guard seconds; prints yes when the ask ended on its own
	local finishLeft="$1"
	while kill -0 "$rigAskPid" 2>/dev/null && [ "$finishLeft" -gt 0 ] ; do sleep 1 ; finishLeft=$(( finishLeft - 1 )) ; done
	if kill -0 "$rigAskPid" 2>/dev/null ; then
		{ kill -TERM -- "-$rigAskPid" ; sleep 1 ; kill -KILL -- "-$rigAskPid" ; wait "$rigAskPid" ; } 2>/dev/null
		printf 'no'
		return 0
	fi
	wait "$rigAskPid" 2>/dev/null || :
	printf 'yes'
}

## A permission question for one refusal, answered in its thread by the addressee.
rigAskPermission(){ ## session id, refusal id, reply text
	printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"%s","thread_ts":"1700000001.000101"}],"has_more":false}\n' "$3" > "$rigScenarioDir/replies.json"
	rm -f "$rigScenarioDir/posts"
	rigTool "$1" AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"$2\",\"reason\":\"the task report goes there\",\"task_ref\":\"dispatch-rig\"}"
}
rigLineOf(){ ## prefix
	LC_ALL=C awk -v wantPrefix="$1" 'index( $0, wantPrefix ) == 1 { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-" wantPrefix "line" ; } }' "$rigScenarioDir/out"
}

## ---------------------------------------------------------------------------
## 12. A permission verdict: allow-once becomes a grant written by the tooling from
##     the record, and the exact retry is admitted once.
## ---------------------------------------------------------------------------
rigStart verdict-allow-once no
rigTarget="$rigScenarioDir/ws/OUT/p.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdP="$( rigRefusalId )"
rigAskPermission rig-session "$rigIdP" "allow-once"
rigAssert "the answer arrived"                             "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "the verdict is allow-once"                      "$( rigLineOf 'VERDICT: ' )" "VERDICT: allow-once"
rigAssert "the tooling wrote the grant"                    "$( rigLineOf 'GRANT: ' )" "GRANT: once $rigIdP"
rigAssert "the post shows the refused call from the record" "$( rigHolds "$rigScenarioDir/post.2" "$rigTarget" )" yes
rigAssert "the grant is signed by the addressee"           "$( rigHolds "$rigScenarioDir/ws/.local/agents/sessions/rig-session/grants" ':URIGOWNER:' )" yes
rigAssert "the exact retry is admitted"                    "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "the next one is refused"                        "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigVerdict "permission allow-once -- the tooling grants from the record, the retry passes once"

## ---------------------------------------------------------------------------
## 13. deny and an unclassifiable answer both write no grant.
## ---------------------------------------------------------------------------
rigStart verdict-deny no
rigTarget="$rigScenarioDir/ws/OUT/q.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigAskPermission rig-session "$( rigRefusalId )" "deny"
rigAssert "the verdict is deny"                            "$( rigLineOf 'VERDICT: ' )" "VERDICT: deny"
rigAssert "no grant is written"                            "$( rigLineOf 'GRANT: ' )" "no-GRANT: line"
rigAssert "the retry is refused"                           "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdLater="$( rigRefusalId )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"maybe later","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rm -f "$rigScenarioDir/posts"
rigTool rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"$rigIdLater\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "an answer naming no option returns UNCLASSIFIED" "$( rigLineOf 'VERDICT: ' )" "VERDICT: UNCLASSIFIED"
rigAssert "and nothing is posted for it"                   "$( cat "$rigScenarioDir/posts" )" 2
rigAssert "and no grants file exists"                      "$( [ -e "$rigScenarioDir/ws/.local/agents/sessions/rig-session/grants" ] && printf yes || printf no )" no
rigRewaitId="$( LC_ALL=C sed -n 's/^AskUserQuestion pending_id=//p' "$rigScenarioDir/out" | tail -1 )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"maybe later","thread_ts":"1700000001.000101"},{"ts":"1700000001.000300","user":"URIGOWNER","text":"deny","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigTool rig-session AskUserQuestion "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "a re-wait on its id finds the valid answer"     "$( rigLineOf 'VERDICT: ' )" "VERDICT: deny"
rigAssert "and still no grant"                             "$( rigLineOf 'GRANT: ' )" "no-GRANT: line"
rigAssert "and the re-wait posted nothing"                 "$( cat "$rigScenarioDir/posts" )" 2
rigTool other-session AskUserQuestion "{\"pending_id\":\"$rigRewaitId\"}"
rigAssert "another session may not re-wait on it"          "$( rigHolds "$rigScenarioDir/out" 'belongs to session rig-session' )" yes
rigVerdict "permission deny, or an unrecognised answer -- nothing is granted, and a re-wait finds the real answer"

## ---------------------------------------------------------------------------
## 14. allow-session: every exact retry in the session, and another member in the
##     same session is not covered by it.
## ---------------------------------------------------------------------------
rigStart verdict-allow-session no
rigTarget="$rigScenarioDir/ws/OUT/r.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdS="$( rigRefusalId )"
rigAskPermission rig-session "$rigIdS" "allow-session"
rigAssert "the tooling wrote a session grant"              "$( rigLineOf 'GRANT: ' )" "GRANT: session $rigIdS"
rigAssert "the first retry is admitted"                    "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "the second retry is admitted"                   "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigAssert "another member in the same session is not"      "$( ( cd "$rigScenarioDir/ws" && printf '{"path":"%s","content":"x"}' "$rigTarget" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID=rig-session RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDAT_SPAWN_AGENT=magic-developer bash "$rigHarness" --intern-tool Write --access-read-root "$rigScenarioDir/ws" --access-write-root "$rigScenarioDir/ws/IN" 2>/dev/null | head -1 ) )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigVerdict "permission allow-session -- the session's member only, every exact retry"

## ---------------------------------------------------------------------------
## 15. The asking account never answers its own permission: addressed to itself
##     and answered by itself, nothing is granted.
## ---------------------------------------------------------------------------
rigStart self-answer no
rigTarget="$rigScenarioDir/ws/OUT/w.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdW="$( rigRefusalId )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"opener"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigTool rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGSELF1\",\"kind\":\"permission\",\"refusal_id\":\"$rigIdW\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "a self-answer is not a verdict"                 "$( rigLineOf 'VERDICT: ' )" "VERDICT: UNCLASSIFIED"
rigAssert "and says why"                                   "$( rigHolds "$rigScenarioDir/out" 'the answer came from the account that asked' )" yes
rigAssert "no grant is written"                            "$( rigLineOf 'GRANT: ' )" "no-GRANT: line"
rigAssert "the retry is still refused"                     "$( rigWriteCall rig-session "$rigTarget" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigTarget"
rigVerdict "no self-approval -- the asking account's own answer grants nothing"

rigStart self-answer-nested no
: > "$rigScenarioDir/post-nested"
rigTarget="$rigScenarioDir/ws/OUT/w.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdW="$( rigRefusalId )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGSELF1","text":"opener"},{"ts":"1700000001.000102","user":"URIGSELF1","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGSELF1","text":"allow-once","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigTool rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGSELF1\",\"kind\":\"permission\",\"refusal_id\":\"$rigIdW\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "a nested user ahead of the sender does not hide the sender" "$( rigLineOf 'VERDICT: ' )" "VERDICT: UNCLASSIFIED"
rigAssert "no grant is written"                            "$( rigLineOf 'GRANT: ' )" "no-GRANT: line"
rigStart self-unknown no
: > "$rigScenarioDir/post-nouser"
rigTarget="$rigScenarioDir/ws/OUT/w.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdW="$( rigRefusalId )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"allow-once","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigTool rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"$rigIdW\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "an unknown asking account takes no answer"      "$( rigLineOf 'VERDICT: ' )" "VERDICT: UNCLASSIFIED"
rigAssert "and says why"                                   "$( rigHolds "$rigScenarioDir/out" 'the asking account could not be established' )" yes
rigAssert "no grant is written"                            "$( rigLineOf 'GRANT: ' )" "no-GRANT: line"
rigVerdict "the asking account is read from the send itself, and unknown means no verdict"

## ---------------------------------------------------------------------------
## 16. A reply whose head carries annotations still reads its first word.
## ---------------------------------------------------------------------------
rigStart annotated-reply no
rigTarget="$rigScenarioDir/ws/OUT/n.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdN="$( rigRefusalId )"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"allow-once","thread_ts":"1700000001.000101","reactions":[{"name":"eyes","count":1,"users":["URIGOTHER"]}]}],"has_more":false}\n' > "$rigScenarioDir/replies.json"
rigTool rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"$rigIdN\",\"reason\":\"r\",\"task_ref\":\"t\"}"
rigAssert "the annotated reply is still the verdict"      "$( rigLineOf 'VERDICT: ' )" "VERDICT: allow-once"
rigVerdict "an annotated reply head is skipped to its first word"

## One team operation, run as a given member in the scenario workspace.
rigOp(){ ## operation and its arguments; the caller's session is RIG_OP_SESSION, or none
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} \
		MMDAPP="$rigScenarioDir/ws" RIG_SCENARIO="$rigScenarioDir" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err"
}
RIG_OP_SESSION="rig-coordinator-session"
## The one pending record of this scenario, once it exists.
rigPendingId(){
	local pendingFile
	for pendingFile in "$rigScenarioDir/ws/.local/agents/pending"/*.md ; do
		[ -f "$pendingFile" ] || continue
		pendingFile="${pendingFile##*/}"
		printf '%s' "${pendingFile%.md}"
		return 0
	done
}
## A permission escalation addressed to a member with no Slack account, left waiting
## in the background; it can only end through the team operation.
rigAskPid=""
rigAskMember(){ ## session id, refusal id, addressee member
	rm -f "$rigScenarioDir/posts"
	set -m
	rigTool "$1" AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task write the refused file?\",\"address_to\":\"$3\",\"kind\":\"permission\",\"refusal_id\":\"$2\",\"reason\":\"the task report goes there\",\"task_ref\":\"dispatch-rig\"}" &
	rigAskPid=$!
	set +m
	local waitLeft=20
	while [ -z "$( rigPendingId )" ] && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}

## ---------------------------------------------------------------------------
## 17. SYNC: an escalation to the coordinator waits until the coordinator answers
##     through the team operation; that same session resumes and the grant is used.
## ---------------------------------------------------------------------------
rigStart answer-by-coordinator no
rigTarget="$rigScenarioDir/ws/OUT/c.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdC="$( rigRefusalId )"
rigAskMember rig-session "$rigIdC" magic-coordinator
rigPending="$( rigPendingId )"
sleep 3
rigAssert "before the answer, the call has not returned"   "$( kill -0 "$rigAskPid" 2>/dev/null && printf waiting || printf returned )" waiting
rigAssert "and its record is open"                         "$( LC_ALL=C awk -F': ' '$1 == "status" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$rigPending.md" )" reply-pending
rigOp --member-escalation-answer magic-developer "$rigPending" allow-once
rigAssert "a member it is not addressed to cannot answer"  "$( rigHolds "$rigScenarioDir/op.err" 'cannot answer it' )" yes
rigOp --member-escalation-answer magic-coordinator "$rigPending" allow-forever
rigAssert "a verdict outside the kind is refused"          "$( rigHolds "$rigScenarioDir/op.err" 'is not a verdict of this permission' )" yes
RIG_OP_SESSION="" ; rigOp --member-escalation-answer magic-coordinator "$rigPending" allow-once ; RIG_OP_SESSION="rig-coordinator-session"
rigAssert "an answer from a caller with no session id is refused" "$( rigHolds "$rigScenarioDir/op.err" 'carries no session id' )" yes
RIG_OP_SESSION="rig-session" ; rigOp --member-escalation-answer magic-coordinator "$rigPending" allow-once ; RIG_OP_SESSION="rig-coordinator-session"
rigAssert "an answer from the asking session itself is refused" "$( rigHolds "$rigScenarioDir/op.err" 'asked from this same session' )" yes
rigOp --member-escalation-answer magic-coordinator "$rigPending" allow-once
rigAssert "the answering session is recorded"      "$( LC_ALL=C awk -F': ' '$1 == "answered-session" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$rigPending.md" )" rig-coordinator-session
rigAssert "the coordinator's answer is applied"            "$( rigHolds "$rigScenarioDir/op.out" "ESCALATION: $rigPending answered" )" yes
rigAssert "and the grant is written from the record"       "$( rigHolds "$rigScenarioDir/op.out" "GRANT: once $rigIdC" )" yes
rigAssert "the waiting call ended on the answer"           "$( rigAskFinish 45 )" yes
rigAssert "it returned RECEIVED"                           "$( rigFirstLine "$rigScenarioDir/out" )" "ASK-RESULT: RECEIVED"
rigAssert "with the verdict"                               "$( rigLineOf 'VERDICT: ' )" "VERDICT: allow-once"
rigAssert "and who gave it"                                "$( rigLineOf 'ANSWERED-BY: ' )" "ANSWERED-BY: magic-coordinator"
rigAssert "the same session's exact retry passes"          "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigOp --member-escalation-answer magic-coordinator "$rigPending" deny
rigAssert "an answered escalation takes no second answer"  "$( rigHolds "$rigScenarioDir/op.err" 'is not open' )" yes
rigOp --member-escalation-read magic-tester "$rigPending"
rigAssert "read returns the recorded verdict"              "$( rigHolds "$rigScenarioDir/op.out" 'VERDICT: allow-once' )" yes
rigVerdict "sync escalation -- waits for the coordinator's answer, resumes the same session, uses the grant"

## ---------------------------------------------------------------------------
## 18. The asking member cannot answer its own escalation through the operation.
## ---------------------------------------------------------------------------
rigStart answer-by-asker no
rigTarget="$rigScenarioDir/ws/OUT/a.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigAskMember rig-session "$( rigRefusalId )" "$rigMember"
rigPending="$( rigPendingId )"
rigOp --member-escalation-answer "$rigMember" "$rigPending" allow-session
rigAssert "the asker's own answer is refused"              "$( rigHolds "$rigScenarioDir/op.err" 'cannot answer it' )" yes
rigAssert "the call is still waiting"                      "$( kill -0 "$rigAskPid" 2>/dev/null && printf waiting || printf returned )" waiting
rigAskFinish 0 > /dev/null
rigVerdict "no self-answer through the operation"

## ---------------------------------------------------------------------------
## 19. Forward: the coordinator forwards to the human-owner, and the human-owner's
##     reply in the forward's thread is the verdict for the original request.
## ---------------------------------------------------------------------------
rigStart forward no
printf 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
rigTarget="$rigScenarioDir/ws/OUT/f.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigIdF="$( rigRefusalId )"
rigAskMember rig-session "$rigIdF" magic-coordinator
rigPending="$( rigPendingId )"
rigOp --magic-escalation-forward magic-developer "$rigPending"
rigAssert "only the addressee forwards"                    "$( rigHolds "$rigScenarioDir/op.err" 'cannot forward it' )" yes
rigOp --magic-escalation-forward magic-coordinator "$rigPending"
rigAssert "the forward is posted and recorded"             "$( rigHolds "$rigScenarioDir/op.out" "ESCALATION: $rigPending forwarded" )" yes
rigForwardTs="$( LC_ALL=C awk -F': ' '$1 == "forward-ts" { print $2 ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$rigPending.md" )"
rigAssert "the record names the forward's thread"          "$( [ -n "$rigForwardTs" ] && printf yes || printf no )" yes
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"forwarded"},{"ts":"1700000009.000900","user":"URIGOWNER","text":"allow-session","thread_ts":"%s"}],"has_more":false}\n' "$rigForwardTs" "$rigForwardTs" > "$rigScenarioDir/replies.json"
rigAssert "the waiting call ended on the human-owner's answer" "$( rigAskFinish 90 )" yes
rigAssert "with the verdict"                               "$( rigLineOf 'VERDICT: ' )" "VERDICT: allow-session"
rigAssert "given by the human-owner's account"             "$( rigLineOf 'ANSWERED-BY: ' )" "ANSWERED-BY: URIGOWNER"
rigAssert "the grant is for the original refusal"          "$( rigLineOf 'GRANT: ' )" "GRANT: session $rigIdF"
rigAssert "the same session's retry passes"                "$( rigWriteCall rig-session "$rigTarget" )" "$( rigOkLine "$rigTarget" )"
rigVerdict "forward -- the human-owner's answer resolves the original request"

## 19b. With both threads unanswered, the reason read out is the forward thread's own.
rigStart forward-reason no
printf 'SLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
rigTarget="$rigScenarioDir/ws/OUT/r.txt"
rigWriteCall rig-session "$rigTarget" > /dev/null
rigAskMember rig-session "$( rigRefusalId )" magic-coordinator
rigPending="$( rigPendingId )"
rigRecord="$rigScenarioDir/ws/.local/agents/pending/$rigPending.md"
rigPendingField(){ ## field -- one value of the pending record
	LC_ALL=C awk -F': ' -v wantField="$1" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$rigRecord"
}
rigAsker="$( rigPendingField asking-accounts | LC_ALL=C awk '{ print $1 ; }' )"
[ -n "$rigAsker" ] || rigRefuse "the record names no asking account, so the question thread's own reason cannot be produced"
## An addressee the question thread is read for: the asking account, whose answer is refused with a reason.
LC_ALL=C awk -v who="$rigAsker" '{ print ; } $0 ~ /^address-to: / { print "addressees: " who ; }' "$rigRecord" > "$rigRecord.rig" && mv -f "$rigRecord.rig" "$rigRecord"
## The reading member holds its own token, so the question thread is read under its own identity.
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/magic-tester.agent.env"
## The question thread holds only the asking account's own answer, which is refused with a reason.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"question"},{"ts":"1700000009.000500","user":"%s","text":"allow-session","thread_ts":"%s"}],"has_more":false}\n' \
	"$( rigPendingField question-ts )" "$rigAsker" "$( rigPendingField thread-ts )" > "$rigScenarioDir/replies.$( rigPendingField thread-ts ).json"
rigOp --member-escalation-read magic-tester "$rigPending"
rigAssert "control: the question thread alone gives its own reason" "$( rigHolds "$rigScenarioDir/op.out" 'VERDICT-REASON: the answer came from the account that asked' )" yes
rigOp --magic-escalation-forward magic-coordinator "$rigPending"
rigForwardTs="$( rigPendingField forward-ts )"
[ -n "$rigForwardTs" ] || rigRefuse "the forward was not recorded, so its thread was never read"
## The forward thread holds a reply naming no answer, which carries no reason of its own.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"forwarded"},{"ts":"1700000009.000900","user":"URIGOWNER","text":"maybe later","thread_ts":"%s"}],"has_more":false}\n' \
	"$rigForwardTs" "$rigForwardTs" > "$rigScenarioDir/replies.$rigForwardTs.json"
rigOp --member-escalation-read magic-tester "$rigPending"
rigAssert "control: the read is still open and unclassified" "$( rigHolds "$rigScenarioDir/op.out" 'VERDICT: UNCLASSIFIED' )" yes
rigAssert "the reason shown is not the question thread's" "$( rigHolds "$rigScenarioDir/op.out" 'VERDICT-REASON: the answer came from the account that asked' )" no
rigAskFinish 0 > /dev/null
rigVerdict "forward -- the reason read out belongs to the forward thread"

## ---------------------------------------------------------------------------
## 20. Planned allows: written on the session's dispatch item, or on the one item it
##     tracks, at planning time; honoured with no refusal and no escalation.
## ---------------------------------------------------------------------------
rigStart planned no
mkdir -p "$rigScenarioDir/ws/DATA/board/running" "$rigScenarioDir/ws/DATA/board/pending"
rigPlanA="$rigScenarioDir/ws/OUT/planned-a.txt"
rigPlanB="$rigScenarioDir/ws/OUT/planned-b.txt"
rigPlanSelf="$rigScenarioDir/ws/OUT/planned-self.txt"
rigPlanOnce="$rigScenarioDir/ws/OUT/planned-once.txt"
printf -- '---\nstatus: dispatch-started\nowner: %s\nsession-id: rig-session\ntracks: task-rig.md\nallows: session:Write:%s:magic-coordinator:20260928T2200Z,session:Write:%s:%s:20260928T2200Z,once:Write:%s:magic-coordinator:20260928T2200Z\n---\n\n# Dispatch\n' \
	"$rigMember" "$rigPlanA" "$rigPlanSelf" "$rigMember" "$rigPlanOnce" > "$rigScenarioDir/ws/DATA/board/running/dispatch-rig.md"
printf -- '---\nstatus: task\nallows: session:Write:%s:magic-coordinator:20260928T2200Z\n---\n\n# Task\n' "$rigPlanB" > "$rigScenarioDir/ws/DATA/board/pending/task-rig.md"
RIG_DATA_ROOT="$rigScenarioDir/ws/DATA"
rigAssert "a planned allow on the dispatch admits its exact call" "$( rigWriteCall rig-session "$rigPlanA" )" "$( rigOkLine "$rigPlanA" )"
rigAssert "a planned allow on the tracked item admits too" "$( rigWriteCall rig-session "$rigPlanB" )" "$( rigOkLine "$rigPlanB" )"
rigAssert "an allow the member planned for itself admits nothing" "$( rigWriteCall rig-session "$rigPlanSelf" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigPlanSelf"
rigAssert "a planned entry that is not session-wide admits nothing" "$( rigWriteCall rig-session "$rigPlanOnce" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigPlanOnce"
rigAssert "another session does not get the plan"          "$( rigWriteCall rig-other "$rigPlanA" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigPlanA"
RIG_DATA_ROOT=""
rigAssert "with no team data store, no planned allow is read" "$( rigWriteCall rig-session "$rigPlanA.2" )" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigPlanA.2"
RIG_DATA_ROOT="$rigScenarioDir/ws/DATA"
rigAssert "control: the planned path under the store is readable again" "$( rigWriteCall rig-session "$rigPlanA" )" "$( rigOkLine "$rigPlanA" )"
RIG_DATA_ROOT=""
rigVerdict "planned allows -- dispatch and tracked item, session-wide, never self-planned"

## ---------------------------------------------------------------------------
## 21. The native PermissionRequest hook: silent in an interactive session, and in an
##     unattended one the same refusal, grant and target the harness gate uses.
## ---------------------------------------------------------------------------
rigHook="$rigHere/client-hooks/permission-request-escalation.sh"
[ -f "$rigHook" ] || rigRefuse "the PermissionRequest hook is missing from the package: $rigHook"
rigHookCall(){ ## unattended (true|empty), session id, hook input JSON
	( cd "$rigScenarioDir/ws" && printf '%s' "$3" | env -u MDAT_DATA_ROOT -u MDAT_SESSION_UNATTENDED -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		${1:+MDAT_SESSION_UNATTENDED="$1"} ${2:+MDAT_SPAWN_SESSION_ID="$2"} ${RIG_ENTRYPOINT:+CLAUDE_CODE_ENTRYPOINT="$RIG_ENTRYPOINT"} MDAT_SPAWN_AGENT="$rigMember" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigHook" ) > "$rigScenarioDir/hook.out" 2> "$rigScenarioDir/hook.err"
}
rigHookBehavior(){
	LC_ALL=C sed -n 's/.*"behavior":"\([a-z]*\)".*/\1/p' "$rigScenarioDir/hook.out" | head -1
}
rigHookId(){
	LC_ALL=C sed -n 's/.*REFUSAL-ID: \(refusal-[0-9a-f-]*\)\..*/\1/p' "$rigScenarioDir/hook.out" | head -1
}
rigStart hook no
rigTarget="$rigScenarioDir/ws/OUT/k.txt"
rigHookInput="{\"session_id\":\"cli-own-id\",\"hook_event_name\":\"PermissionRequest\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$rigTarget\",\"content\":\"x\"}}"
RIG_ENTRYPOINT=cli rigHookCall "" "" "$rigHookInput"
rigAssert "an interactive session gets no decision, so Claude Code prompts as usual" "$( cat "$rigScenarioDir/hook.out" )" ""
rigHookCall "" "" "$rigHookInput"
rigAssert "a launch with no entrypoint and no marker is unattended, and decided" "$( rigHookBehavior )" deny
rigHookCall true rig-session "$rigHookInput"
rigAssert "an unattended call with no grant is denied"     "$( rigHookBehavior )" deny
rigHookIdK="$( rigHookId )"
rigAssert "with a recorded refusal id"                     "$( rigRecordField "$rigHookIdK" tool )" Write
rigAssert "keyed to the same resolved target the harness uses" "$( rigRecordField "$rigHookIdK" target )" "$rigTarget"
rigAssert "the message points to the escalation"           "$( rigHolds "$rigScenarioDir/hook.out" 'AskUserQuestion kind=permission' )" yes
rigGrant magic-coordinator rig-session "$rigHookIdK" once > /dev/null
rigHookCall true rig-session "$rigHookInput"
rigAssert "an Allow once is allowed by the hook"           "$( rigHookBehavior )" allow
rigHookCall true rig-session "$rigHookInput"
rigAssert "and used up"                                    "$( rigHookBehavior )" deny
rigHookCall true rig-other "$rigHookInput"
rigAssert "another session is denied"                      "$( rigHookBehavior )" deny
rigCommandInput='{"session_id":"x","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/rig  x"}}'
rigHookCall true rig-session "$rigCommandInput"
rigHookIdC="$( rigHookId )"
rigAssert "a command is recorded by its exact text"        "$( rigRecordField "$rigHookIdC" target )" "rm -rf /tmp/rig  x"
rigGrant magic-coordinator rig-session "$rigHookIdC" session > /dev/null
rigHookCall true rig-session "$rigCommandInput"
rigAssert "a session grant allows the exact command"       "$( rigHookBehavior )" allow
rigHookCall true rig-session '{"session_id":"x","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/rig x"}}'
rigAssert "a reworded command is a new refusal"            "$( rigHookBehavior )" deny
( cd "$rigScenarioDir/ws" && printf '%s' "$rigHookInput" | env MDAT_SESSION_UNATTENDED=true MDAT_SPAWN_SESSION_ID=rig-session MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN=/nonexistent bash "$rigHook" ) > "$rigScenarioDir/hook.out" 2>/dev/null
rigAssert "with the tooling unreachable it still denies, saying why" "$( rigHolds "$rigScenarioDir/hook.out" 'could not be reached' )" yes
rigVerdict "PermissionRequest hook -- silent when attended, the gate's own refusal and grant when unattended"

## ---------------------------------------------------------------------------
## 22. Harness and hook key the same call to the same target: a plain path, a
##     symlinked parent, a missing parent.
## ---------------------------------------------------------------------------
rigStart equivalence no
mkdir -p "$rigScenarioDir/ws/REAL"
ln -s "$rigScenarioDir/ws/REAL" "$rigScenarioDir/ws/LINKED"
for rigEqPath in "$rigScenarioDir/ws/OUT/plain.txt" "$rigScenarioDir/ws/LINKED/via-link.txt" "$rigScenarioDir/ws/NOPE/missing.txt" ; do
	rigWriteCall rig-session "$rigEqPath" > /dev/null
	rigEqHarness="$( rigRecordField "$( rigRefusalId )" target )"
	rigHookCall true rig-session "{\"session_id\":\"x\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$rigEqPath\",\"content\":\"x\"}}"
	rigEqHook="$( rigRecordField "$( rigHookId )" target )"
	rigAssert "harness and hook agree on ${rigEqPath##*/}"   "$rigEqHook" "$rigEqHarness"
	[ "${rigEqPath##*/}" != "via-link.txt" ] || rigEqLinked="$rigEqHarness"
done
rigAssert "the symlinked parent was resolved"              "$rigEqLinked" "$rigScenarioDir/ws/REAL/via-link.txt"
rigAssert "a missing parent is compared as given"          "$rigEqHarness" "$rigScenarioDir/ws/NOPE/missing.txt"
rigVerdict "the harness gate and the hook resolve one call to one target"

rigUnknown="$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C awk '$0 ~ /^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' )"
rigAssert "no request went anywhere but a Slack method"    "$rigUnknown" 0
rigVerdict "offline -- every request was answered by the fake"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_PERMISSION: OK (%d scenarios, %d assertions, offline)\n' "$rigScenarioCount" "$rigPassCount"
