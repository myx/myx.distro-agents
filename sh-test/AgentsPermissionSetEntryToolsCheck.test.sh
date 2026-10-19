#!/usr/bin/env bash
## Behavioural check on which tools an entry of a Permission set may name
## (--magic-permission-set-request, AgentsTools.InternOpPermission.include). Covers: an entry
## names any tool the permission model can decide on, and those are listed in one place,
## the model's own (agentsPermissionEntryTools, AgentsTools.PermissionHolds.include): the file
## tools, and the others a gate asks about by name, Artifact, Agent, Bash, cred and spend among
## them; a tool of an MCP server is named by its own name; a team tool every member holds is
## known too; a name the model does not know at all is a CORRECTION, rc 6, that names the
## ones it does, for a single-tool entry and for a comma list alike, and nothing is asked;
## and the post shows each tool as it was asked.
## Red recipe: a single-tool entry with a misspelt tool was taken as it stood, and a list
## took only ten fixed names, so `Artifact,Agent:<target>` was returned as not known.
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only
## is beside it, and everything runs in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTools" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTools"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPermissionSetEntryToolsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST. A spawn is found running by a process list read from the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own, and another copy of this check for its own. So the ps
## first on PATH answers the whole-host listing from the rig's own list, beside it, one
## `<pid> <command line>` line a process, and hands every other call to the real ps.
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
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
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG"
}

## The rig workspace: a session rig-set of three participants, each spawn on its own host; a
## dispatch that tracks a task; the workspace registered as the place rig-ws; one standing row,
## so one asked entry is held by a participant already.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-set" "$rigData/board/running" "$rigData/board/processed" "$rigWs/DEV"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'magic-developer:ws:workspace:Edit(/%s/DEV/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
rigSetRecord(){ ## spawn id, owner, host, description, further header lines (may be empty)
	printf -- '---\nsession-id: rig-set\nspawn-id: %s\nowner: %s\nhost: %s\ndescription: %s\n%sstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "$2" "$3" "$4" "${5:-}" > "$rigWs/.local/agents/spawned/rig-set/$1.md"
}
rigSetRecord rig-set magic-coordinator rig-host-a 'rework the vars loader' $'session-thread: CRIG00001:1700000000.000500\n'
## The developer's spawn runs on this host, live: an entry counts as held only by a participant
## with a live run in the session, a line of the rig's process list that runs as its spawn id.
rigSetRecord rig-set-dev magic-developer "$( hostname -s 2>/dev/null || echo unknown )" 'change the loader code'
printf '900001 rig-run --session-id rig-set-dev\n' >> "$rigTmp/ps.list"
## A task set is for the members it names: these three, in the task requests below.
rigSetThree=( --participant magic-coordinator --participant magic-developer --participant magic-tester )
rigSetRecord rig-set-tester magic-tester rig-host-c 'check it against the samples'
printf -- '---\nstatus: task\nowner: magic-developer\n---\n\n# Fix the vars loader\n\nThe loader drops a variable whose value holds an equals sign.\n' > "$rigData/board/running/task-rig-set.md"
printf -- '---\nstatus: dispatch-started\nowner: magic-developer\nsession-id: rig-set\ntracks: task-rig-set\n---\n\n# Spawn-proxy dispatch: magic-developer\n\n## Brief\n\nthe brief of the dispatch.\n' \
	> "$rigData/board/running/dispatch-rig-set.md"
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
rigSetAsk(){ ## item, request options... -> the pending id
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-set
	rigOp --magic-permission-set-request magic-coordinator "$@"
	RIG_OP_AGENT="" RIG_OP_SESSION=""
	LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out"
}
rigWithdraw(){ ## pending id, reason, [the member that withdraws; default the asker]
	RIG_OP_AGENT="${3:-magic-coordinator}" RIG_OP_SESSION=rig-set
	rigOp --member-pending-reply-settle "${3:-magic-coordinator}" "$1" --reason "$2" --withdraw
	RIG_OP_AGENT="" RIG_OP_SESSION=""
}
rigGrantRead(){ ## member, session, tool, target
	rigOp --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1
}
## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## What an edit must carry: the text the post was sent with, less its how-to-answer part.
rigClosedOf(){ ## the body file of the post
	rigTextOf "$1" | LC_ALL=C sed 's/\\n\\n\*\*✅ How to answer\*\*.*$//'
}
## Whether an edit is a whole message as the send builds one: it names the post it edits, has
## blocks, and says nowhere how to answer -- "<names it>:<blocks>:<how to answer>".
rigEditShape(){ ## edit body file, ts of the post
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	printf '%s:%s:%s' "$( LC_ALL=C grep -c -F "\"ts\":\"$2\"" "$1" )" "$( LC_ALL=C grep -c -F '"blocks":[' "$1" )" "$( LC_ALL=C grep -c -e 'to allow the set' -e 'allow-set' "$1" )"
}
## The emoji placed on, or taken off, one post: its names in the order asked for.
rigReacted(){ ## reactions|reactions.removed, ts
	LC_ALL=C awk -v want="$2" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigTmp/$1" 2>/dev/null
}
## The post of one request: the body file the fake curl kept for the message its record names.
rigPostOf(){ ## pending id
	local postTs postFile
	postTs="$( rigField "$rigWs/.local/agents/pending/$1.md" question-ts )"
	for postFile in "$rigTmp"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		[ "1700000001.000${postFile##*.}01" != "$postTs" ] || { printf '%s' "$postFile" ; return 0 ; }
	done
	printf '%s' "$rigTmp/no-such-post"
}

## One set request as the coordinator, whatever comes of it: its rc as rigRc.
rigRc=0
rigSetTry(){ ## item, request options...
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-set
	rigRc=0
	rigOp --magic-permission-set-request magic-coordinator "$@" || rigRc=$?
	RIG_OP_AGENT="" RIG_OP_SESSION=""
}
rigLine(){ ## file, line -> how many lines of the file are that text
	LC_ALL=C awk -v wantLine="$2" '$0 == wantLine { hitCount++ ; } END { print hitCount + 0 ; }' "$1" 2>/dev/null
}
## The names the model's own list holds, as a correction says them.
rigKnown="$( MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include" ; printf "%s" "$agentsPermissionEntryTools"' 2>/dev/null | LC_ALL=C sed 's/^ *//;s/ *$//;s/  */, /g' )"
## The names of those given that the model's own list lacks.
rigLacking(){ ## names...
	local lackName
	for lackName in "$@" ; do
		case ", $rigKnown," in
			*", $lackName,"*) ;;
			*) printf '%s ' "$lackName" ;;
		esac
	done
}
rigAssert "the model's own list names the file tools and the others a gate asks about" \
	"$( rigLacking Read Grep Glob Edit Write Execute Bash WebFetch WebSearch Agent Artifact cred spend )" ""

echo "-- a name the model does not know at all: a correction that names the ones it does, and nothing is asked --"
rigSetTry dispatch-rig-set --entry 'Raed:/nowhere/rig-set/one' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "a single-tool entry: rc 6, nothing posted or recorded, and the first word on stderr is CORRECTION" \
	"$rigRc:$( rigCalls chat.postMessage ):$( ls "$rigWs/.local/agents/pending" 2>/dev/null | LC_ALL=C grep -c . ):$( LC_ALL=C grep -c '^CORRECTION: ' "$rigTmp/op.err" )" "6:0:0:1"
rigAssert "it names the tool it does not know, and every name the model's list holds" \
	"$( rigHas "$rigTmp/op.err" "names a tool the permission model does not know: 'Raed'" ):$( rigHas "$rigTmp/op.err" ": $rigKnown;" )" "yes:yes"
rigSetTry dispatch-rig-set --entry 'Read,Raed:/nowhere/rig-set/one' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "a comma list with one such name: the same" \
	"$rigRc:$( rigCalls chat.postMessage ):$( rigHas "$rigTmp/op.err" "names a tool the permission model does not know: 'Raed'" ):$( rigHas "$rigTmp/op.err" ": $rigKnown;" )" "6:0:yes:yes"
rigSetTry dispatch-rig-set --entry 'Read,,Glob:/nowhere/rig-set/one' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "a list with a name left empty: a correction too" "$rigRc:$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c '^CORRECTION: ' "$rigTmp/op.err" )" "6:0:1"
rigSetTry dispatch-rig-set --entry 'read:/nowhere/rig-set/one' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "a name is taken as it is written: read in small letters is no tool" "$rigRc:$( rigCalls chat.postMessage )" "6:0"

echo "-- any tool the model can decide on is asked, alone or in a list, and the post shows each as asked --"
rigSetTry dispatch-rig-set --entry 'Artifact:publish' --entry 'Agent' --entry 'spend:rig-budget' --entry 'Bash,Read:/nowhere/rig-set/two' \
	--entry 'mcp__rig__tool' --entry 'Artifact,Agent:/nowhere/rig-set/three' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "asked: rc 0 and one post" "$rigRc:$( rigCalls chat.postMessage ):$( LC_ALL=C grep -c '^PERMISSION-SET: asked ' "$rigTmp/op.out" )" "0:1:1"
rigAssert "a tool beyond the ten of before is an entry: Artifact, Agent, spend, each as asked" \
	"$( rigLine "$rigTmp/op.out" 'EXTRA: Artifact:publish' ):$( rigLine "$rigTmp/op.out" 'EXTRA: Agent' ):$( rigLine "$rigTmp/op.out" 'EXTRA: spend:rig-budget' )" "1:1:1"
rigAssert "a list takes them too, one entry a tool, a native tool name among them" \
	"$( rigLine "$rigTmp/op.out" 'EXTRA: Bash:/nowhere/rig-set/two' ):$( rigLine "$rigTmp/op.out" 'EXTRA: Read:/nowhere/rig-set/two' ):$( rigLine "$rigTmp/op.out" 'EXTRA: Artifact:/nowhere/rig-set/three' ):$( rigLine "$rigTmp/op.out" 'EXTRA: Agent:/nowhere/rig-set/three' )" "1:1:1:1"
rigAssert "a tool of an MCP server is named by its own name" "$( rigLine "$rigTmp/op.out" 'EXTRA: mcp__rig__tool' )" "1"
rigSetId="$( LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out" )"
rigAssert "the set keeps each entry exactly as asked" \
	"$( rigLine "$rigWs/.local/agents/pending/$rigSetId.set" 'entry: Artifact:publish' ):$( rigLine "$rigWs/.local/agents/pending/$rigSetId.set" 'entry: Bash:/nowhere/rig-set/two' ):$( rigLine "$rigWs/.local/agents/pending/$rigSetId.set" 'entry: mcp__rig__tool' ):$( LC_ALL=C grep -c '^entry: ' "$rigWs/.local/agents/pending/$rigSetId.set" )" "1:1:1:8"
rigAssert "and the post shows each tool as it was asked" \
	"$( for rigName in Artifact Agent spend Bash Read mcp__rig__tool ; do printf '%s ' "$( rigHas "$rigTmp/post.1" "$rigName" )" ; done )" "yes yes yes yes yes yes "
rigSetTry dispatch-rig-set --entry 'SendMessage' --scope task --session-id rig-set "${rigSetThree[@]}"
rigAssert "accepted sibling: a team tool every member holds is known, and is held, so nothing more is asked" \
	"$rigRc:$( LC_ALL=C grep -c '^CORRECTION: ' "$rigTmp/op.err" ):$( LC_ALL=C grep -c '^HELD: SendMessage by ' "$rigTmp/op.out" ):$( rigCalls chat.postMessage )" "0:0:1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION SET ENTRY TOOLS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PERMISSION_SET_ENTRY_TOOLS: OK (%d assertions, offline)\n' "$rigPassCount"
