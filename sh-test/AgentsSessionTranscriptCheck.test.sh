#!/usr/bin/env bash
## Behavioural check on the tooling-written session transcript (T5): the one tool-line
## formatter, a transcript's creation, pointers and roll-over, the tool lines and message
## events of the harness loop and the MCP paths, the daemon log (no per-server calls log),
## token-like values redacted on a line, the stream-json writer of a
## native spawn with its usage, SessionTranscriptAppend (tool, and the op with no
## --transcript-name), and the milestone
## commits, counted.
## Offline, and self-contained in its scratch: MMDAPP, the team-data store (a temp git
## repository) and HOME are fixtures; the model rounds come from a fake curl first on
## PATH; nothing is posted and the real store is never reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigFormat="$rigHere/AgentsSessionTranscriptFormat.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigFormat" ] || rigRefuse "the formatter is missing: $rigFormat"
[ -f "$rigHere/AgentsTools.SessionTranscript.include" ] || rigRefuse "the transcript include is missing"
command -v git > /dev/null || rigRefuse "git is not installed"

rigTmp="$( mktemp -d -t AgentsSessionTranscriptCheck )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] || rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigStore/board/running" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/skills/magic-tester"
printf 'rig-tester\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
git -C "$rigStore" init -q || rigRefuse "could not init the temp store"
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the temp store"
unset CLAUDE_CODE_SESSION_ID MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_MCP_SERVED_MARKER MDAT_MCP_CALLS_LOG MDAT_SESSION_ID harnessSessionId
export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN HOME="$rigTmp/home"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, fixed text -- 1 when some line holds it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null | awk '{ print ( $1 > 0 ) ? 1 : 0 }'
}
rigCommits(){ git -C "$rigStore" rev-list --count HEAD ; }

. "$rigHere/AgentsTools.SessionTranscript.include"

echo "-- the one formatter --"
rigLine="$( printf '%s' '{"file_path":"/a/b c.txt","offset":10,"limit":5,"content":"SECRET-BODY"}' \
	| STL_TS=T0 STL_TOOL=mcp__myx_distro__Read STL_OUTCOME=ok STL_BYTES=120 STL_LINES=4 STL_DUR_MS=35 STL_COMMENT='reading "it"' LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a Read line carries path, offset, limit, size, duration and the comment" "$rigLine" 'T0 TOOL mcp__myx_distro__Read path="/a/b c.txt" offset=10 limit=5 -> ok 120B/4L 35ms | "reading \"it\""'
rigLine="$( printf '%s' '{"pattern":"a|b","path":"/p","glob":"*.sh","output_mode":"content"}' | STL_TS=T0 STL_TOOL=Grep STL_OUTCOME=ok LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a Grep line carries pattern, path, glob and mode" "$rigLine" 'T0 TOOL Grep pattern="a|b" path=/p glob="*.sh" mode=content -> ok'
rigLine="$( printf '%s' '{"command":"ls -la\nrm -rf x","description":"List it"}' | STL_TS=T0 STL_TOOL=execute STL_OUTCOME=error STL_FIRST='ERROR: boom' STL_DUR_MS=2500 STL_COMMENT='model text' LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a command is its first line only, and the call's own description wins as the comment" "$rigLine" 'T0 TOOL execute cmd="ls -la" -> error "ERROR: boom" 2.5s | "List it"'
rigAssert "file content never reaches a line" "$( printf '%s' '{"file_path":"/f","content":"SECRET-BODY"}' | STL_TS=T0 STL_TOOL=Write STL_OUTCOME=ok LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" | LC_ALL=C grep -c SECRET )" 0
rigLine="$( printf 'one\ntwo\x01three\n' | STL_CAP=9 LC_ALL=C awk -v stlStandalone=body -f "$rigFormat" )"
rigAssert "a body is > lines, control bytes folded, cut with its full size named" "$rigLine" $'> one\n> two t\n> [... cut at 9 of 13 bytes]'
rigLine="$( printf 'to\tC1:2.3\nempty\t\nwho\tmagic tester\n' | STL_TS=T0 STL_KIND=MSG-OUT LC_ALL=C awk -v stlStandalone=event -f "$rigFormat" )"
rigAssert "an event line quotes what needs it and drops an empty value" "$rigLine" 'T0 MSG-OUT to=C1:2.3 who="magic tester"'
rigLine="$( printf '%s' '{"command":"SLACK_BOT_TOKEN=xoxb-11-22-abc curl -H \"Authorization: Bearer rig.bearer-9\" -d PASSWORD=rigpass https://x\nsecond line"}' \
	| STL_TS=T0 STL_TOOL=execute STL_OUTCOME=ok LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a command's first line keeps its shape, every token-like value [redacted]" "$rigLine" \
	'T0 TOOL execute cmd="SLACK_BOT_TOKEN=[redacted] curl -H \"Authorization: Bearer [redacted]\" -d PASSWORD=[redacted] https://x" -> ok'
rigLine="$( printf '%s' '{"query":"xapp-1-A0-rig sk-rigABCDEFGHIJKLMNOPQRSTU ghp_rigABCDEFGHIJKLMNOPQRSTUVWXYZ0123 gho_rigABCDEFGHIJKLMNOPQRSTUVWXYZ0123 github_pat_11RIG0123456789_abcdef AKIARIGABCDEFGHIJKLM task-rigABCDEFGHIJKLMNOPQRSTU"}' \
	| STL_TS=T0 STL_TOOL=ToolSearch STL_OUTCOME=ok LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "app, sk-, GitHub and AWS key forms are [redacted] in an argument; a word with -sk- inside is not" "$rigLine" \
	'T0 TOOL ToolSearch query="[redacted] [redacted] [redacted] [redacted] [redacted] [redacted] task-rigABCDEFGHIJKLMNOPQRSTU" -> ok'
rigLine="$( printf '%s' '{"command":"ls"}' | STL_TS=T0 STL_TOOL=execute STL_OUTCOME=error STL_FIRST='ERROR: token xoxp-9-8-rig refused' STL_COMMENT='set RIG_API_KEY=rig-key-value' LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a result's first line and the comment are redacted too" "$rigLine" 'T0 TOOL execute cmd=ls -> error "ERROR: token [redacted] refused" | "set RIG_API_KEY=[redacted]"'
rigLine="$( printf 'to\tC1:2.3\nwho\tRIG_SECRET=rig-secret-value\n' | STL_TS=T0 STL_KIND=NOTE LC_ALL=C awk -v stlStandalone=event -f "$rigFormat" )"
rigAssert "and an event line's values" "$rigLine" 'T0 NOTE to=C1:2.3 who="RIG_SECRET=[redacted]"'

echo "-- a transcript's creation, pointers and roll-over --"
rigSid="aaaa1111-0000-4000-8000-000000000001"
rigRel="$( AgentsTranscriptNewRel magic-tester "$rigSid" )"
case "$rigRel" in
	audit/[0-9][0-9][0-9][0-9]-[0-9][0-9]/session-[0-9]*T[0-9]*Z-magic-tester-aaaa1111.log) rigAssert "the name is audit/YYYY-MM/session-<startUTC>-<member>-<sid8>.log" ok ok ;;
	*) rigAssert "the name is audit/YYYY-MM/session-<startUTC>-<member>-<sid8>.log" "$rigRel" "audit/YYYY-MM/session-...-magic-tester-aaaa1111.log" ;;
esac
AgentsTranscriptStart "$rigSid" "$rigStore" "$rigRel" magic-tester service claude-native parent none item dispatch-rig.md
AgentsTranscriptSetItem "$rigSid" dispatch-rig.md
rigT="$rigStore/$rigRel"
rigAssert "the file starts with its START line" "$( head -1 "$rigT" | sed 's/^[^ ]* //' )" "START session=$rigSid member=magic-tester service=claude-native parent=none item=dispatch-rig.md"
rigAssert "sessions/<sid>/transcript points at it" "$( cat "$rigWs/.local/agents/sessions/$rigSid/transcript" )" "$rigT"
rigAssert "the session's item is recorded" "$( cat "$rigWs/.local/agents/sessions/$rigSid/dispatch-item" )" dispatch-rig.md
rigAssert "AgentsTranscriptPath resolves it from the session id alone" "$( AgentsTranscriptPath "$rigSid" )" "$rigT"
rigAssert "a session with no pointer resolves nothing" "$( AgentsTranscriptPath no-such-session >/dev/null && echo yes || echo no )" no
rigRollSid="aaaa1111-0000-4000-8000-0000000000ff"
AgentsTranscriptStart "$rigRollSid" "$rigStore" "audit/2026-10/session-roll.log" magic-tester
printf '%0400d\n' 0 >> "$rigStore/audit/2026-10/session-roll.log"
rigRollPart="$( MDAT_TRANSCRIPT_ROLL_BYTES=300 AgentsTranscriptPath "$rigRollSid" )"
rigAssert "past the roll size the next part is -part2" "${rigRollPart##*/}" session-roll-part2.log
rigAssert "the old part names where it went" "$( tail -1 "$rigStore/audit/2026-10/session-roll.log" | sed 's/^[^ ]* //' )" "ROLL -> session-roll-part2.log"
rigAssert "every part is listed" "$( AgentsTranscriptParts "$rigRollSid" | sed 's|.*/||' | tr '\n' ' ' )" "session-roll.log session-roll-part2.log "

echo "-- tool lines and message events, and the milestones they commit --"
export MDAT_SPAWN_SESSION_ID="$rigSid"
rigBefore="$( rigCommits )"
AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read '{"file_path":"/x/y","limit":3}' $'a\nb\nc' loop
AgentsTranscriptToolStart Bash ; AgentsTranscriptToolDone Bash '{"command":"false"}' $'ERROR: exit 1\nthe detail' loop
AgentsTranscriptToolStart Edit ; AgentsTranscriptToolDone Edit '{"file_path":"/x"}' 'ERROR: refused by a PreToolUse hook' loop refused
AgentsTranscriptToolStart SendMessage ; AgentsTranscriptToolDone SendMessage '{"to":"C1:2.3","message":"hello\nworld"}' 'Sent to C1' loop
AgentsTranscriptToolStart SubagentHandback ; AgentsTranscriptToolDone SubagentHandback '{"task":"T","outcome":"done","findings":"F"}' 'Sent' loop
AgentsTranscriptToolStart Wait ; AgentsTranscriptToolDone Wait '{}' $'WAIT-RESULT: RECEIVED\nfrom human: go on' loop
AgentsTranscriptToolStart Wait ; AgentsTranscriptToolDone Wait '{}' $'WAIT-RESULT: DISMISSED\nWAIT-DISMISSED-BY: human' loop
AgentsTranscriptToolStart AskUserQuestion ; AgentsTranscriptToolDone AskUserQuestion '{"to":"human-owner","question":"Which one?"}' 'ANSWER: the second' loop
rigAssert "a Read line" "$( rigHas "$rigT" 'TOOL Read path=/x/y limit=3 -> ok 5B/3L' )" 1
rigAssert "an error keeps its first line on the line" "$( rigHas "$rigT" 'TOOL Bash cmd=false -> error "ERROR: exit 1" 24B/2L' )" 1
rigAssert "and the error in full below it" "$( rigHas "$rigT" '> the detail' )" 1
rigAssert "a refusal is marked refused" "$( rigHas "$rigT" 'TOOL Edit path=/x -> refused "ERROR: refused by a PreToolUse hook"' )" 1
rigAssert "a message out keeps its full text" "$( LC_ALL=C grep -A2 'MSG-OUT to=C1:2.3' "$rigT" | tail -2 | tr '\n' '|' )" '> hello|> world|'
rigAssert "a handback keeps its report" "$( rigHas "$rigT" '> outcome: done' )" 1
rigAssert "a Wait result keeps its text" "$( LC_ALL=C grep -A2 ' WAIT-RESULT$' "$rigT" | tail -1 )" '> from human: go on'
rigAssert "DISMISSED is its own event" "$( rigHas "$rigT" ' DISMISSED' )" 1
rigAssert "an ask and its answer are both kept" "$( rigHas "$rigT" 'ASK to=human-owner' )$( rigHas "$rigT" '> ANSWER: the second' )" 11
rigAssert "milestones: message out, handback, wait going idle x2, dismissed, ask" "$( awk '{ $1 = "" ; print }' "$rigWs/.local/agents/sessions/$rigSid/milestones" | tr '\n' '|' )" ' message out| handback| wait going idle| wait going idle| dismissed| message out|'
rigAssert "each milestone with something new is one commit; a Wait with nothing new is none" "$(( $( rigCommits ) - rigBefore ))" 5
rigAssert "and the transcript is committed clean" "$( git -C "$rigStore" status --porcelain -- "$rigRel" )" ""
rigAssert "a session with no transcript writes nothing and fails nothing" "$( MDAT_SPAWN_SESSION_ID=nobody AgentsTranscriptToolDone Read '{}' x loop ; echo rc=$? )" rc=0

echo "-- SessionTranscriptAppend, the function, the op with no --transcript-name, the tool --"
rigAssert "a line goes to the current session's transcript" "$( AgentsTranscriptNote "$rigSid" magic-tester 'trying the second way' | cut -c1-15 )" "OK: appended to"
rigAssert "the NOTE line and its text" "$( LC_ALL=C grep -A1 'NOTE by=magic-tester' "$rigT" | tail -1 )" '> trying the second way'
rigAssert "no session is refused" "$( AgentsTranscriptNote '' magic-tester x ; echo " rc=$?" )" "ERROR: no session resolves for this call (no session id in this process), so there is no transcript to note in. Nothing was written.
 rc=1"
rigAssert "a session with no transcript is refused" "$( AgentsTranscriptNote no-such magic-tester x | cut -c1-36 )" "ERROR: session no-such has no transc"
rigOut="$( "$rigFn" --member-append-session-transcript magic-tester --message 'from the op' 2>/dev/null )"
rigAssert "the op with no --transcript-name resolves the session itself" "$rigOut" "OK: appended to ${rigT##*/}"
rigAssert "the op's line is there" "$( rigHas "$rigT" '> from the op' )" 1
rigAssert "speaker defaults to the member, timestamp to now (UTC)" "$( LC_ALL=C grep -B1 '^> from the op$' "$rigT" | head -1 | LC_ALL=C grep -Ec ' NOTE by=magic-tester at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' )" 1
"$rigFn" --member-append-session-transcript magic-tester --speaker human-owner --timestamp 2026-10-08T01:02:03Z --message 'given speaker' > /dev/null 2>&1
rigAssert "a given speaker and timestamp are kept" "$( LC_ALL=C grep -B1 '^> given speaker$' "$rigT" | head -1 | sed 's/^[^ ]* //' )" "NOTE by=human-owner at=2026-10-08T01:02:03Z"
rigOut="$( MDAT_SPAWN_SESSION_ID= "$rigFn" --member-append-session-transcript magic-tester --message 'no session line' 2>&1 ; echo "rc=$?" )"
rigAssert "the op refuses where no session resolves" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=1
rigAssert "and says so" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'ERROR: .*--member-append-session-transcript: no session resolves' )" 1
rigAssert "and writes nothing" "$( rigHas "$rigT" '> no session line' )" 0
rigOut="$( "$rigFn" --member-append-session-transcript magic-tester --message 'create on existing' --create 2>&1 ; echo "rc=$?" )"
rigAssert "--create on a session that has a transcript just appends" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=0
rigAssert "into that same transcript" "$( rigHas "$rigT" '> create on existing' )" 1
rigOut="$( MDAT_SPAWN_SESSION_ID= "$rigFn" --member-append-session-transcript magic-tester --session-id "$rigSid" --message 'by session id' 2>&1 ; echo "rc=$?" )"
rigAssert "a member cannot name another session (--session-id is refused)" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=1
rigAssert "and nothing is written" "$( rigHas "$rigT" '> by session id' )" 0
rigOut="$( MDAT_SPAWN_SESSION_ID= "$rigFn" --member-append-session-transcript magic-tester --speaker x --timestamp 2026-10-08T01:02:03Z --message 'by name' --transcript-name "${rigT##*/}" 2>&1 ; echo "rc=$?" )"
rigAssert "a member cannot name a session's own log" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=1
rigAssert "and nothing is written to it" "$( rigHas "$rigT" '> by name' )" 0
rigOut="$( MDAT_SPAWN_SESSION_ID= "$rigFn" --magic-append-session-transcript magic-coordinator "$rigSid" --message 'by the coordinator' 2>&1 ; echo "rc=$?" )"
rigAssert "the coordinator appends to a session it names" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=0
rigAssert "and the line is in that session's transcript" "$( rigHas "$rigT" '> by the coordinator' )" 1
rigOut="$( "$rigFn" --magic-append-session-transcript magic-coordinator --message 'no id' 2>&1 ; echo "rc=$?" )"
rigAssert "the coordinator op needs a session id" "$( printf '%s\n' "$rigOut" | tail -1 )" rc=1
rigOut="$( MDAT_SPAWN_AGENT=magic-developer "$rigFn" --member-append-session-transcript magic-tester --message 'impersonated' 2>&1 ; echo "rc=$?" )"
rigAssert "a spawned session appends as no other member" "$( printf '%s\n' "$rigOut" | tail -1 ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'this session acts as magic-developer' ):$( rigHas "$rigT" '> impersonated' )" rc=1:1:0
rigOut="$( MDAT_SPAWN_AGENT=magic-tester "$rigFn" --member-append-session-transcript magic-tester --message 'as itself' 2>&1 ; echo "rc=$?" )"
rigAssert "and appends as its own member" "$( printf '%s\n' "$rigOut" | tail -1 ):$( rigHas "$rigT" '> as itself' )" rc=0:1
rigOut="$( MDAT_SPAWN_AGENT=magic-developer MDAT_SKILLSET_ROOT="$rigTmp/skills" "$rigFn" --member-append-session-transcript magic-tester --speaker magic-tester --timestamp 2026-10-08T01:02:03Z --message 'shared, impersonated' --transcript-name transcript-2026-10-08-rig-access.md --create 2>&1 ; echo "rc=$?" )"
rigAssert "a named transcript is refused to a session naming another member" "$( printf '%s\n' "$rigOut" | tail -1 ):$( [ -f "$rigStore/audit/2026-10/transcript-2026-10-08-rig-access.md" ] && echo written || echo absent )" rc=1:absent
rigOut="$( MDAT_SPAWN_AGENT=magic-tester MDAT_SKILLSET_ROOT="$rigTmp/skills" "$rigFn" --member-append-session-transcript magic-tester --speaker magic-tester --timestamp 2026-10-08T01:02:03Z --message 'shared, as itself' --transcript-name transcript-2026-10-08-rig-access.md --create 2>&1 ; echo "rc=$?" )"
rigAssert "and taken from the member's own session" "$( printf '%s\n' "$rigOut" | tail -1 ):$( rigHas "$rigStore/audit/2026-10/transcript-2026-10-08-rig-access.md" '> shared, as itself' )" rc=0:1
rigOut="$( MDAT_SPAWN_SESSION_ID= "$rigFn" --magic-append-session-transcript magic-tester "$rigSid" --message 'not the coordinator' 2>&1 ; echo "rc=$?" )"
rigAssert "the coordinator op runs as magic-coordinator only" "$( printf '%s\n' "$rigOut" | tail -1 ):$( rigHas "$rigT" '> not the coordinator' )" rc=1:0
rigOut="$( MDAT_SPAWN_SESSION_ID= MDAT_SPAWN_AGENT=magic-tester "$rigFn" --magic-append-session-transcript magic-coordinator "$rigSid" --message 'a member as the coordinator' 2>&1 ; echo "rc=$?" )"
rigAssert "and from no member's session naming it" "$( printf '%s\n' "$rigOut" | tail -1 ):$( rigHas "$rigT" '> a member as the coordinator' )" rc=1:0
rigOut="$( printf '%s' '{"note":"served note"}' | MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-tester "$rigHarness" --intern-tool SessionTranscriptAppend 2>/dev/null )"
rigAssert "the SessionTranscriptAppend tool appends through the served harness" "$rigOut" "OK: appended to ${rigT##*/}"
rigAssert "with the member as speaker" "$( LC_ALL=C grep -A1 'NOTE by=magic-tester' "$rigT" | tail -1 )" '> served note'
rigOut="$( printf '%s' '{"note":"x"}' | MDAT_SPAWN_SESSION_ID= MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-tester "$rigHarness" --intern-tool SessionTranscriptAppend 2>/dev/null )"
rigAssert "the tool refuses with ERROR where no session resolves" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^ERROR: .*--member-append-session-transcript: no session resolves' )" 1

echo "-- the MCP paths: execute, a served tool, a refusal; the daemon log --"
printf 'rig file line\n' > "$rigWs/rig.txt"
rigServe(){ ## wire out, stderr out, then request lines
	local serveOut="$1" serveErr="$2"
	shift 2
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' "$@" | (
		cd "$rigWs" && MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT=magic-tester \
			bash "$rigFn" --intern-mcp-server --run > "$serveOut" 2> "$serveErr"
	) || :
}
rigServe "$rigTmp/wire1" "$rigTmp/err1" \
	'{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$rigWs"'/rig.txt"}}}' \
	'{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"execute","arguments":{"command":"echo hi\nexit 3"}}}' \
	'{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"Bash","arguments":{"command":"ls"}}}'
LC_ALL=C grep -q '"id":4,' "$rigTmp/wire1" || { sed 's/^/    /' "$rigTmp/err1" >&2 ; rigRefuse "the rig server did not answer every call" ; }
rigAssert "no per-server calls log is created" "$( [ -e "$rigWs/.local/agents/mcp-calls" ] && echo created || echo none ):$( find "$rigWs/.local" -name 'myx.distro.*.log' 2>/dev/null | LC_ALL=C grep -c . )" none:0
rigAssert "the served Read reaches the transcript, its access refusal marked refused" "$( LC_ALL=C grep -c "TOOL Read path=[^ ]*/rig.txt -> refused \"ERROR: path not in the allowed access-root set" "$rigT" )" 1
rigAssert "execute reaches it, with its command and its exit as the first line" "$( rigHas "$rigT" 'TOOL execute cmd="echo hi" -> error "[exit code: 3]"' )" 1
rigAssert "a refused call reaches it too" "$( rigHas "$rigT" 'TOOL Bash cmd=ls -> error "ERROR: Bash is not served' )" 1
rigAssert "the daemon log holds every call, each prefixed by its session" "$( LC_ALL=C grep -c '^aaaa1111 [^ ]* TOOL ' "$rigTmp/err1" )" 3
rigAssert "the daemon log line is the transcript's line" "$( LC_ALL=C grep "^aaaa1111 [^ ]* TOOL Read " "$rigTmp/err1" | cut -d" " -f2- )" "$( LC_ALL=C grep " TOOL Read path=[^ ]*/rig.txt" "$rigT" )"
: > "$rigWs/.local/agents/sessions/$rigSid/transcript.stream"
rigBeforeLines="$( LC_ALL=C grep -c ' TOOL ' "$rigT" )"
rigServe "$rigTmp/wire2" "$rigTmp/err2" '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"'"$rigWs"'/rig.txt"}}}'
rigAssert "a native spawn's own stream writes its tool lines: the served call adds none" "$( LC_ALL=C grep -c ' TOOL ' "$rigT" )" "$rigBeforeLines"
rigAssert "while the daemon log still gets it, with its session" "$( LC_ALL=C grep -c '^aaaa1111 [^ ]* TOOL Read ' "$rigTmp/err2" )" 1
rm -f "$rigWs/.local/agents/sessions/$rigSid/transcript.stream"

echo "-- the harness model loop: rounds, tokens, text, tools, restart, final --"
cp "$rigTest/check-fixtures/harness-restart-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
rigLoopSid="cccc3333-0000-4000-8000-000000000003"
rigLoop="$rigTmp/loop"
mkdir -p "$rigLoop"
printf '0' > "$rigLoop/round"
printf 'RIG-READ\n' > "$rigLoop/read.txt"
printf 'data: {"choices":[{"index":0,"delta":{"content":"Reading the rig file."}}]}\n' > "$rigLoop/res.1"
printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"c1","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"%s\\"}"}}]}}]}\n' "$rigLoop/read.txt" >> "$rigLoop/res.1"
printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":100,"completion_tokens":7,"total_tokens":107,"prompt_tokens_details":{"cached_tokens":60}}}\ndata: [DONE]\n' >> "$rigLoop/res.1"
printf 'data: {"choices":[{"index":0,"delta":{"content":"NOTES-FOR-RESTART"},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}\ndata: [DONE]\n' > "$rigLoop/res.2"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-FINAL-ANSWER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":20,"completion_tokens":3,"total_tokens":23}}\ndata: [DONE]\n' > "$rigLoop/res.3"
AgentsTranscriptStart "$rigLoopSid" "$rigStore" "audit/2026-10/session-loop.log" magic-tester
rigLoopT="$rigStore/audit/2026-10/session-loop.log"
(
	unset MDAT_SPAWN_SESSION_ID
	PATH="$rigTmp/bin:$PATH" RIG_SCENARIO="$rigLoop" MDAT_HARNESS_CONTEXT_TOKENS=50 \
	HARNESS_PROVIDER_NAME="transcript rig" HARNESS_SELF_NAME=AgentsSessionTranscriptCheck.test.sh \
	HARNESS_ENDPOINT="https://transcript-check.invalid/v1/chat/completions" HARNESS_HOST=transcript-check.invalid \
	HARNESS_WIRE=OpenAiChat HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT=rig-light HARNESS_MODEL_MAIN=rig-main \
	HARNESS_TOKEN_LIGHT=rig-not-a-credential HARNESS_TOKEN_MAIN=rig-not-a-credential \
	"$rigHarness" --session-id "$rigLoopSid" --access-root "$rigLoop" RIG-TASK > "$rigLoop/out" 2> "$rigLoop/err"
) || :
[ "$( cat "$rigLoop/round" )" = 3 ] || { sed 's/^/    /' "$rigLoop/err" >&2 ; rigRefuse "the harness did not run its three rounds" ; }
rigAssert "the MODEL line names model, service and tier" "$( rigHas "$rigLoopT" 'MODEL model=rig-main service="transcript rig" host=transcript-check.invalid tier=normal' )" 1
rigAssert "a round keeps its tokens: input, cache-read, cache-write, output" "$( rigHas "$rigLoopT" 'ROUND n=1 in=40 cache-read=60 cache-write=0 out=7' )" 1
rigAssert "and its visible text" "$( LC_ALL=C grep -A1 'ROUND n=1 ' "$rigLoopT" | tail -1 )" '> Reading the rig file.'
rigAssert "the tool line carries the text before it as its comment" "$( rigHas "$rigLoopT" "TOOL Read path=$rigLoop/read.txt -> ok" )$( rigHas "$rigLoopT" '| "Reading the rig file."' )" 11
rigAssert "a restart is logged with its summary size" "$( LC_ALL=C grep -c 'RESTART n=1 summary=[0-9]*B' "$rigLoopT" )" 1
rigAssert "the final answer is kept" "$( LC_ALL=C grep -A1 ' FINAL' "$rigLoopT" | tail -1 )" '> RIG-FINAL-ANSWER'
rigAssert "the session's running token sum" "$( cat "$rigWs/.local/agents/sessions/$rigLoopSid/tokens" )" "70 60 0 15"
rigAssert "restart and final answer were milestones" "$( awk '{ $1 = "" ; print }' "$rigWs/.local/agents/sessions/$rigLoopSid/milestones" | tr '\n' '|' )" ' restart 1| final answer|'

echo "-- a native spawn: the stream-json writer --"
rigStreamSid="bbbb2222-0000-4000-8000-000000000002"
AgentsTranscriptStart "$rigStreamSid" "$rigStore" "audit/2026-10/session-stream.log" magic-tester
rigStreamT="$rigStore/audit/2026-10/session-stream.log"
{
	printf '%s\n' '{"type":"system","subtype":"init","cwd":"/x","session_id":"cli-1","tools":["Read"],"model":"claude-opus-5-5"}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"thinking","thinking":"SECRET-THOUGHT"}],"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":5}}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Let me look."}],"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":20}}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"tool_use","id":"tu_1","name":"mcp__myx_distro__Grep","input":{"pattern":"x","path":"/p"}},{"type":"tool_use","id":"tu_2","name":"Bash","input":{"command":"ls","description":"List"}}],"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":40}}}'
	printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"tu_1","type":"tool_result","content":[{"type":"text","text":"a\nb"}]}]}}'
	printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"tu_2","type":"tool_result","content":"PreToolUse:Bash hook error: blocked","is_error":true}]}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_2","type":"message","role":"assistant","content":[{"type":"text","text":"Done."}],"usage":{"input_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":1200,"output_tokens":7}}}'
	printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"result":"All done.","session_id":"cli-1","total_cost_usd":0.0123,"usage":{"input_tokens":13,"cache_creation_input_tokens":100,"cache_read_input_tokens":2200,"output_tokens":47}}'
} > "$rigTmp/stream.jsonl"
rigStreamAwk(){
	LC_ALL=C awk -f "$rigHere/AgentsProgressLineSafe.awk" -f "$rigFormat" -f "$rigHere/AgentsClaudeStreamJsonTranscript.awk" -f "$rigHere/AgentsClaudeStreamJsonFormat.awk" < "$rigTmp/stream.jsonl"
}
rigOut="$( MDAT_SPAWN_SESSION_ID="$rigStreamSid" rigStreamAwk 2>/dev/null )"
rigAssert "the progress formatter still prints the result" "$rigOut" "All done."
rigAssert "the model" "$( rigHas "$rigStreamT" 'MODEL model=claude-opus-5-5 service=claude-native' )" 1
rigAssert "a native tool line with its arguments, size and the text before it" "$( rigHas "$rigStreamT" 'TOOL mcp__myx_distro__Grep pattern=x path=/p -> ok 3B/2L <1s | "Let me look."' )" 1
rigAssert "a hook refusal is refused, kept in full" "$( rigHas "$rigStreamT" 'TOOL Bash cmd=ls -> refused "PreToolUse:Bash hook error: blocked"' )$( rigHas "$rigStreamT" '> PreToolUse:Bash hook error: blocked' )" 11
rigAssert "each round's tokens" "$( rigHas "$rigStreamT" 'ROUND n=1 in=10 cache-read=1000 cache-write=100 out=40' )$( rigHas "$rigStreamT" 'ROUND n=2 in=3 cache-read=1200 cache-write=0 out=7' )" 11
rigAssert "thinking is never kept" "$( LC_ALL=C grep -c SECRET-THOUGHT "$rigStreamT" )" 0
rigAssert "the result with its usage" "$( rigHas "$rigStreamT" 'RESULT outcome=ok turns=2 in=13 cache-read=2200 cache-write=100 out=47' )" 1
rigAssert "the session's tokens, as the CLI reported its usage" "$( cat "$rigWs/.local/agents/sessions/$rigStreamSid/tokens" )" "13 2200 100 47"
rigAssert "the served path is told this session's stream writes its tool lines" "$( [ -e "$rigWs/.local/agents/sessions/$rigStreamSid/transcript.stream" ] && echo yes )" yes
rigAssert "with no session the progress output is byte-identical to the formatter alone" \
	"$( MDAT_SPAWN_SESSION_ID= rigStreamAwk 2>&1 | cksum )" "$( LC_ALL=C awk -f "$rigHere/AgentsProgressLineSafe.awk" -f "$rigHere/AgentsClaudeStreamJsonFormat.awk" < "$rigTmp/stream.jsonl" 2>&1 | cksum )"
rigAssert "a native round keeps its visible text after its tokens" "$( LC_ALL=C grep -A1 'ROUND n=1 ' "$rigStreamT" | tail -1 )" '> Let me look.'

echo "-- a native spawn: model text redacted, a provider or CLI error kept before the first tool --"
rigErrSid="dddd4444-0000-4000-8000-000000000004"
AgentsTranscriptStart "$rigErrSid" "$rigStore" "audit/2026-10/session-native-error.log" magic-tester
rigErrT="$rigStore/audit/2026-10/session-native-error.log"
{
	printf '%s\n' 'Error: the CLI failed with Bearer rig-bearer-value'
	printf '%s\n' '{"type":"system","subtype":"init","cwd":"/x","session_id":"cli-4","tools":["Read"],"model":"claude-opus-5-5"}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Using RIG_API_KEY=rig-key-value now."}],"usage":{"input_tokens":1,"output_tokens":2}}}'
	printf '%s\n' '{"type":"assistant","message":{"id":"msg_e","model":"<synthetic>","role":"assistant","content":[{"type":"text","text":"API Error: 401 token xoxp-9-8-rig is invalid"}]},"session_id":"cli-4","error":"authentication_failed"}'
	printf '%s\n' '{"type":"result","subtype":"error_during_execution","is_error":true,"num_turns":1,"session_id":"cli-4","total_cost_usd":0,"usage":{"input_tokens":1,"output_tokens":2},"errors":["RIG-CLI-FAILURE"]}'
} > "$rigTmp/stream-error.jsonl"
( MDAT_SPAWN_SESSION_ID="$rigErrSid" LC_ALL=C awk -f "$rigHere/AgentsProgressLineSafe.awk" -f "$rigFormat" -f "$rigHere/AgentsClaudeStreamJsonTranscript.awk" -f "$rigHere/AgentsClaudeStreamJsonFormat.awk" < "$rigTmp/stream-error.jsonl" > /dev/null 2>&1 ) || :
rigAssert "the CLI's own error line is an ERROR, redacted" "$( rigHas "$rigErrT" ' ERROR source=cli' )$( rigHas "$rigErrT" '> Error: the CLI failed with Bearer [redacted]' )" 11
rigAssert "the provider error is an ERROR with its kind, in full, redacted" "$( rigHas "$rigErrT" ' ERROR source=provider kind=authentication_failed' )$( rigHas "$rigErrT" '> API Error: 401 token [redacted] is invalid' )" 11
rigAssert "the round text is redacted" "$( rigHas "$rigErrT" '> Using RIG_API_KEY=[redacted] now.' )" 1
rigAssert "a result with no text keeps the CLI's own errors" "$( rigHas "$rigErrT" '> RIG-CLI-FAILURE' )" 1
rigAssert "no secret reaches the transcript" "$( LC_ALL=C grep -c -e rig-bearer-value -e rig-key-value -e xoxp-9-8-rig "$rigErrT" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION TRANSCRIPT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_TRANSCRIPT: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
